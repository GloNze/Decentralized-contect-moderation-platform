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
