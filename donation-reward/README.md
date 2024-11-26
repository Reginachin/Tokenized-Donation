# Tokenized Donation Smart Contract

## About
A Clarity smart contract that enables organizations to manage donations with automated token rewards. The system tracks donations, issues reward tokens, and provides comprehensive donor analytics.

## Features
- **Tokenized Donations:** Automatically issues reward tokens for donations
- **Donor Tracking:** Comprehensive tracking of donor statistics and history
- **Reward System:** Bonus tokens for reaching donation thresholds
- **Donation Categories:** Support for categorized donations
- **Streak Tracking:** Monitors consecutive donation patterns
- **Administrative Controls:** Secure management functions for contract owners

## Contract Information
- **File:** `tokenized-donation-manager.clar`
- **Version:** 1.0.0
- **Network:** Stacks Mainnet
- **Dependencies:** 
  - NFT Trait (`SP2PABAF9FTAJYNFZH93XENAJ8FVY99RRM50D2JG9.nft-trait.nft-trait`)
  - Fungible Token Standard

## Technical Specifications

### Constants
```clarity
MINIMUM_REWARD_THRESHOLD_MULTIPLIER: u10
REWARD_TOKEN_PERCENTAGE: u10
BLOCKS_PER_DAY: u144
```

### Error Codes
| Code | Description |
|------|-------------|
| u100 | Owner Only Operation |
| u101 | Invalid Amount |
| u102 | Unauthorized Access |
| u103 | Already Claimed |
| u104 | Invalid Address |
| u105 | Contract Paused |
| u106 | Transfer Failed |
| u107 | Insufficient Balance |
| u108 | Invalid Token ID |
| u109 | Not Found |
| u110 | Zero Amount |

## Public Functions

### Donation Management
```clarity
(submit-donation (donation-amount uint) (donation-category (optional (string-ascii 64))))
```
Submit a donation and receive reward tokens.

**Parameters:**
- `donation-amount`: Amount in STX to donate
- `donation-category`: Optional category for the donation

### Reward Claims
```clarity
(claim-donor-rewards)
```
Claim bonus rewards for reaching donation thresholds.

### Administrative Functions
```clarity
(update-minimum-donation (new-minimum-amount uint))
(toggle-contract-pause)
(withdraw-contract-funds (withdrawal-amount uint))
```

### Read-Only Functions
```clarity
(get-donor-information (donor-address principal))
(get-donation-transaction (donation-id uint))
(get-contract-statistics)
```

## Data Structures

### Donor Statistics
```clarity
{
    lifetime-donation-amount: uint,
    total-donation-count: uint,
    last-donation-block: uint,
    rewards-claim-status: bool,
    donation-streak: uint
}
```

### Donation Transaction Records
```clarity
{
    donor-address: principal,
    donation-amount: uint,
    transaction-block: uint,
    donation-token-id: uint,
    donation-category: (optional (string-ascii 64))
}
```

## Usage Examples

### Making a Donation
```clarity
;; Submit a donation of 100 STX
(contract-call? .tokenized-donation-manager submit-donation u100000000 none)

;; Submit a categorized donation
(contract-call? .tokenized-donation-manager submit-donation u100000000 (some "education"))
```

### Claiming Rewards
```clarity
;; Claim available rewards
(contract-call? .tokenized-donation-manager claim-donor-rewards)
```

### Checking Donor Status
```clarity
;; Get donor information
(contract-call? .tokenized-donation-manager get-donor-information tx-sender)
```

## Security Considerations

### Access Control
- Contract owner functions are protected
- Pause mechanism for emergency stops
- Donation thresholds to prevent abuse

### Best Practices
- Use secure STX transfer methods
- Validate all inputs
- Follow token standards
- Implement proper error handling

## Maintenance

### Upgrading
1. Deploy new version
2. Migrate data if needed
3. Update documentation

### Monitoring
- Track donation patterns
- Monitor token distribution
- Check system statistics

## Contributing
1. Fork the repository
2. Create feature branch
3. Submit pull request
4. Follow coding standards