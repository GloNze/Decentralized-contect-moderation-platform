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