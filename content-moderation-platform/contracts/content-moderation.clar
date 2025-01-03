;; Decentralized Content Moderation Contract
;; Allows users to submit content, vote on moderation decisions, and manage reputation

;; Constants
(define-constant ERR-NOT-AUTHORIZED (err u1))
(define-constant ERR-ALREADY-VOTED (err u2))
(define-constant ERR-CONTENT-NOT-FOUND (err u3))
(define-constant ERR-INSUFFICIENT-REPUTATION (err u4))
(define-constant ERR-INVALID-STAKE (err u5))
(define-constant ERR-ALREADY-STAKED (err u6))
(define-constant ERR-NO-STAKE-FOUND (err u7))
(define-constant ERR-COOLDOWN-ACTIVE (err u8))
(define-constant ERR-INVALID-REPORT (err u9))

(define-constant MIN_STAKE_AMOUNT u1000)
(define-constant REPORT_THRESHOLD u3)
(define-constant STAKE_LOCKUP_PERIOD u720) ;; ~5 days in blocks
(define-constant COOLDOWN_PERIOD u72) ;; ~12 hours in blocks
(define-constant CHALLENGER_REWARD_PERCENTAGE u5) ;; 5% of stake
(define-constant VOTING_PERIOD u144) ;; ~24 hours in blocks
(define-constant MIN_REPUTATION u100)
(define-constant VOTE_REWARD u10)


;; Data Maps
(define-map contents 
    { content-id: uint }
    {
        author: principal,
        content-hash: (buff 32),
        status: (string-ascii 20),
        created-at: uint,
        votes-for: uint,
        votes-against: uint,
        voting-ends-at: uint
    }
)

(define-map user-reputation
    { user: principal }
    { score: uint }
)

(define-map user-votes
    { content-id: uint, voter: principal }
    { vote: bool }
)

;; Additional Data Maps
(define-map moderator-stakes
    { moderator: principal }
    {
        amount: uint,
        locked-until: uint,
        active: bool
    }
)

(define-map content-reports
    { content-id: uint }
    {
        report-count: uint,
        reporters: (list 10 principal),
        resolved: bool
    }
)

(define-map user-cooldowns
    { user: principal }
    { cooldown-until: uint }
)

(define-map content-challenges
    { content-id: uint, challenger: principal }
    {
        stake-amount: uint,
        challenge-time: uint,
        resolved: bool,
        successful: bool
    }
)


;; Variables
(define-data-var content-counter uint u0)


;; Private Functions
(define-private (is-voting-period-active (content-id uint))
    (match (map-get? contents { content-id: content-id })
        content (< block-height (get voting-ends-at content))
        false
    )
)

(define-private (has-sufficient-reputation (user principal))
    (let (
        (reputation (default-to { score: u0 } (map-get? user-reputation { user: user })))
    )
        (>= (get score reputation) MIN_REPUTATION)
    )
)

;; Submit new content for moderation
(define-public (submit-content (content-hash (buff 32)))
    (let (
        (content-id (+ (var-get content-counter) u1))
    )
        (map-set contents
            { content-id: content-id }
            {
                author: tx-sender,
                content-hash: content-hash,
                status: "pending",
                created-at: block-height,
                votes-for: u0,
                votes-against: u0,
                voting-ends-at: (+ block-height VOTING_PERIOD)
            }
        )
        (var-set content-counter content-id)
        (ok content-id)
    )
)

;; Vote on content moderation
(define-public (vote (content-id uint) (approve bool))
    (let (
        (content (unwrap! (map-get? contents { content-id: content-id }) ERR-CONTENT-NOT-FOUND))
        (voter-reputation (default-to { score: u0 } (map-get? user-reputation { user: tx-sender })))
    )
        (asserts! (is-voting-period-active content-id) ERR-NOT-AUTHORIZED)
        (asserts! (has-sufficient-reputation tx-sender) ERR-INSUFFICIENT-REPUTATION)
        (asserts! (is-none (map-get? user-votes { content-id: content-id, voter: tx-sender })) ERR-ALREADY-VOTED)
        
        (map-set user-votes 
            { content-id: content-id, voter: tx-sender }
            { vote: approve }
        )
        
        (map-set contents
            { content-id: content-id }
            (merge content {
                votes-for: (if approve (+ (get votes-for content) u1) (get votes-for content)),
                votes-against: (if (not approve) (+ (get votes-against content) u1) (get votes-against content))
            })
        )
        
        ;; Update voter reputation
        (map-set user-reputation
            { user: tx-sender }
            { score: (+ (get score voter-reputation) VOTE_REWARD) }
        )
        
        (ok true)
    )
)

;; Finalize moderation decision
(define-public (finalize-moderation (content-id uint))
    (let (
        (content (unwrap! (map-get? contents { content-id: content-id }) ERR-CONTENT-NOT-FOUND))
    )
        (asserts! (not (is-voting-period-active content-id)) ERR-NOT-AUTHORIZED)
        
        (map-set contents
            { content-id: content-id }
            (merge content {
                status: (if (> (get votes-for content) (get votes-against content))
                    "approved"
                    "rejected"
                )
            })
        )
        (ok true)
    )
)

;; Read-only Functions

;; Get content details
(define-read-only (get-content (content-id uint))
    (map-get? contents { content-id: content-id })
)

;; Get user reputation
(define-read-only (get-user-reputation (user principal))
    (default-to { score: u0 } (map-get? user-reputation { user: user }))
)

;; Check if user has voted on specific content
(define-read-only (has-voted (content-id uint) (user principal))
    (is-some (map-get? user-votes { content-id: content-id, voter: user }))
)

;; Staking Functions

;; Stake tokens to become a moderator
(define-public (stake-tokens (amount uint))
    (let (
        (current-stake (default-to { amount: u0, locked-until: u0, active: false } 
            (map-get? moderator-stakes { moderator: tx-sender })))
    )
        (asserts! (>= amount MIN_STAKE_AMOUNT) ERR-INVALID-STAKE)
        (asserts! (not (get active current-stake)) ERR-ALREADY-STAKED)
        
        ;; Transfer tokens from user to contract
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        
        (map-set moderator-stakes
            { moderator: tx-sender }
            {
                amount: amount,
                locked-until: (+ block-height STAKE_LOCKUP_PERIOD),
                active: true
            }
        )
        (ok true)
    )
)

;; Unstake tokens after lockup period
(define-public (unstake-tokens)
    (let (
        (stake (unwrap! (map-get? moderator-stakes { moderator: tx-sender }) ERR-NO-STAKE-FOUND))
    )
        (asserts! (get active stake) ERR-NO-STAKE-FOUND)
        (asserts! (>= block-height (get locked-until stake)) ERR-NOT-AUTHORIZED)
        
        ;; Transfer tokens back to user
        (try! (as-contract (stx-transfer? (get amount stake) tx-sender tx-sender)))
        
        (map-set moderator-stakes
            { moderator: tx-sender }
            {
                amount: u0,
                locked-until: u0,
                active: false
            }
        )
        (ok true)
    )
)