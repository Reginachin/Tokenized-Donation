;; Tokenized Donation Smart Contract
;; Allows users to make donations and receive donation tokens as proof
;; Implements features like donation tracking, rewards, and administrative controls

;; Define NFT Trait
(define-trait nft-trait
  (
    ;; Transfer a token from one principal to another
    (transfer (uint principal principal) (response bool uint))
    
    ;; Get the owner of a specific token ID
    (get-owner (uint) (response (optional principal) uint))
    
    ;; Get the last token ID (for total supply)
    (get-last-token-id () (response uint uint))
    
    ;; Get the URI for a specific token
    (get-token-uri (uint) (response (optional (string-utf8 256)) uint))
  )
)

;; Error Constants
(define-constant ERR_OWNER_ONLY (err u100))
(define-constant ERR_INVALID_AMOUNT (err u101))
(define-constant ERR_UNAUTHORIZED (err u102))
(define-constant ERR_ALREADY_CLAIMED (err u103))
(define-constant ERR_INVALID_ADDRESS (err u104))
(define-constant ERR_CONTRACT_PAUSED (err u105))
(define-constant ERR_TRANSFER_FAILED (err u106))
(define-constant ERR_INSUFFICIENT_BALANCE (err u107))
(define-constant ERR_INVALID_TOKEN_ID (err u108))
(define-constant ERR_NOT_FOUND (err u109))
(define-constant ERR_ZERO_AMOUNT (err u110))

;; System Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant DONATION_TOKEN_URI "https://donation-token.uri")
(define-constant MINIMUM_REWARD_THRESHOLD_MULTIPLIER u10)
(define-constant REWARD_TOKEN_PERCENTAGE u10)
(define-constant BLOCKS_PER_DAY u144) ;; Average blocks per day for time calculations

;; Data Variables
(define-data-var minimum-donation-amount uint u1000000) ;; 1 STX
(define-data-var cumulative-donation-amount uint u0)
(define-data-var unique-donor-count uint u0)
(define-data-var contract-paused bool false)
(define-data-var donation-cycle-number uint u0)

;; Data Maps
(define-map donor-statistics 
    principal 
    {
        lifetime-donation-amount: uint,
        total-donation-count: uint,
        last-donation-block: uint,
        rewards-claim-status: bool,
        donation-streak: uint
    }
)

(define-map donation-transaction-records 
    uint 
    {
        donor-address: principal,
        donation-amount: uint,
        transaction-block: uint,
        donation-token-id: uint,
        donation-category: (optional (string-ascii 64))
    }
)

;; SFT Interface
(define-fungible-token donation-reward-token)

;; Private Functions
(define-private (is-authorized-owner)
    (is-eq tx-sender CONTRACT_OWNER)
)

(define-private (get-donor-records (donor-address principal))
    (default-to 
        {
            lifetime-donation-amount: u0,
            total-donation-count: u0,
            last-donation-block: u0,
            rewards-claim-status: false,
            donation-streak: u0
        }
        (map-get? donor-statistics donor-address)
    )
)

(define-private (update-donor-records 
    (donor-address principal) 
    (donation-amount uint)
)
    (let (
        (current-donor-data (get-donor-records donor-address))
        (new-donation-count (+ (get total-donation-count current-donor-data) u1))
        (updated-donation-amount (+ (get lifetime-donation-amount current-donor-data) donation-amount))
        (current-streak (get donation-streak current-donor-data))
        (last-donation-height (get last-donation-block current-donor-data))
        (donation-streak-updated (if (< (- block-height last-donation-height) BLOCKS_PER_DAY)
            (+ current-streak u1)
            u1))
    )
    (map-set donor-statistics 
        donor-address
        {
            lifetime-donation-amount: updated-donation-amount,
            total-donation-count: new-donation-count,
            last-donation-block: block-height,
            rewards-claim-status: (get rewards-claim-status current-donor-data),
            donation-streak: donation-streak-updated
        }
    ))
)

;; Public Functions
(define-public (submit-donation (donation-amount uint) (donation-category (optional (string-ascii 64))))
    (begin
        (asserts! (not (var-get contract-paused)) ERR_CONTRACT_PAUSED)
        (asserts! (> donation-amount u0) ERR_ZERO_AMOUNT)
        (asserts! (>= donation-amount (var-get minimum-donation-amount)) ERR_INVALID_AMOUNT)
        
        ;; Process STX transfer
        (try! (stx-transfer? donation-amount tx-sender (as-contract tx-sender)))
        
        ;; Update global statistics
        (var-set cumulative-donation-amount (+ (var-get cumulative-donation-amount) donation-amount))
        (update-donor-records tx-sender donation-amount)
        
        ;; Issue donation reward tokens
        (try! (ft-mint? donation-reward-token donation-amount tx-sender))
        
        ;; Record donation transaction
        (map-set donation-transaction-records 
            (var-get donation-cycle-number)
            {
                donor-address: tx-sender,
                donation-amount: donation-amount,
                transaction-block: block-height,
                donation-token-id: (var-get donation-cycle-number),
                donation-category: donation-category
            }
        )
        
        ;; Increment donation cycle
        (var-set donation-cycle-number (+ (var-get donation-cycle-number) u1))
        
        ;; Update unique donor count if first time donor
        (if (is-eq (get total-donation-count (get-donor-records tx-sender)) u1)
            (var-set unique-donor-count (+ (var-get unique-donor-count) u1))
            true
        )
        
        (ok true)
    )
)

(define-public (claim-donor-rewards)
    (let (
        (donor-record (get-donor-records tx-sender))
    )
    (begin
        (asserts! (not (var-get contract-paused)) ERR_CONTRACT_PAUSED)
        (asserts! (>= (get lifetime-donation-amount donor-record) 
            (* (var-get minimum-donation-amount) MINIMUM_REWARD_THRESHOLD_MULTIPLIER)) 
            ERR_INSUFFICIENT_BALANCE)
        (asserts! (not (get rewards-claim-status donor-record)) ERR_ALREADY_CLAIMED)
        
        ;; Update reward claim status
        (map-set donor-statistics 
            tx-sender
            (merge donor-record { rewards-claim-status: true })
        )
        
        ;; Mint bonus reward tokens
        (try! (ft-mint? donation-reward-token 
            (/ (get lifetime-donation-amount donor-record) REWARD_TOKEN_PERCENTAGE) 
            tx-sender))
        
        (ok true)
    ))
)

;; Administrative Functions
(define-public (update-minimum-donation (new-minimum-amount uint))
    (begin
        (asserts! (is-authorized-owner) ERR_OWNER_ONLY)
        (asserts! (> new-minimum-amount u0) ERR_ZERO_AMOUNT)
        (var-set minimum-donation-amount new-minimum-amount)
        (ok true)
    )
)

(define-public (toggle-contract-pause)
    (begin
        (asserts! (is-authorized-owner) ERR_OWNER_ONLY)
        (var-set contract-paused (not (var-get contract-paused)))
        (ok true)
    )
)

(define-public (withdraw-contract-funds (withdrawal-amount uint))
    (begin
        (asserts! (is-authorized-owner) ERR_OWNER_ONLY)
        (asserts! (> withdrawal-amount u0) ERR_ZERO_AMOUNT)
        (try! (as-contract (stx-transfer? withdrawal-amount tx-sender CONTRACT_OWNER)))
        (ok true)
    )
)

;; Read-only Functions
(define-read-only (get-donor-information (donor-address principal))
    (match (map-get? donor-statistics donor-address)
        donor-data (ok donor-data)
        ERR_NOT_FOUND
    )
)

(define-read-only (get-donation-transaction (donation-id uint))
    (match (map-get? donation-transaction-records donation-id)
        transaction-data (ok transaction-data)
        ERR_NOT_FOUND
    )
)

(define-read-only (get-contract-statistics)
    (ok {
        total-donation-amount: (var-get cumulative-donation-amount),
        total-unique-donors: (var-get unique-donor-count),
        current-minimum-donation: (var-get minimum-donation-amount),
        contract-status: (var-get contract-paused),
        current-donation-cycle: (var-get donation-cycle-number)
    })
)

;; Error Handling
(define-private (handle-operation-result (operation-result (response bool uint)) (error-code uint))
    (match operation-result
        success (ok true)
        error (err error-code)
    )
)