(define-constant coupon-creator 'SP3GHS3JVCBPW4K0HJ95VCKZ6EDWV08YMZ85XQGN0)

(define-non-fungible-token coupon uint)

;; Error
(define-constant err-mint-failed (err u1))
(define-constant err-invalid-code (err u2))
(define-constant err-transfer-failed (err u3))
(define-constant err-transfer-not-allowed (err u4))
(define-constant err-code-used (err u5))
(define-constant err-cannot-use (err u6))

;; Variables
(define-data-var next-code uint u1)
(define-data-var total-code uint u0)

(define-map coupons
  ((coupon-code uint))
  ((discount uint) (used bool))
)

;; get owner of a coupon
(define-read-only (owner-of? (coupon-code uint))
  (nft-get-owner? coupon coupon-code)
)

;; check is owner of a coupon
(define-private (is-owner (actor principal) (coupon-code uint))
  (is-eq actor
    (unwrap! (nft-get-owner? coupon coupon-code) false)
  )
)

;; The coupon-creator create a coupon to receiver
;; By default, the created coupons belong to the coupon-creator
(define-public (create-coupon (discount uint))
  (let ((coupon-code (var-get next-code)))
    (if
      (and
        (is-eq tx-sender coupon-creator)
        (is-ok (nft-mint? coupon coupon-code coupon-creator))
      )
      (begin
        (map-set coupons {coupon-code: coupon-code}
          {
            discount: discount,
            used: false
          }
        )
        (var-set next-code (+ coupon-code u1))
        (var-set total-code (+ (var-get total-code) u1))
        (ok coupon-code)
      )
      err-mint-failed
    )
  )
)

(define-private (is-valid (coupon-code uint))
  (is-some (map-get? coupons {coupon-code: coupon-code}))
)

;; get total code
(define-public (get-total-code)
  (ok (var-get total-code))
)

;; check coupon code is valid or not
(define-public (check-coupon-valid (coupon-code uint))
  (if (is-valid coupon-code)
    (ok true)
    (ok false)
  )
)

;; get owner of a valid coupon code
(define-public (get-owner-of (coupon-code uint))
  (if (is-valid coupon-code)
    (ok (default-to coupon-creator (owner-of? coupon-code)))
    err-invalid-code
  )
)

;; check coupon discount rate
(define-public (check-coupon-discount (coupon-code uint))
  (if (is-valid coupon-code)
    (ok (default-to u0 (get discount (map-get? coupons {coupon-code: coupon-code}))))
    err-invalid-code
  )
)

;; check coupon was used or not
(define-public (check-coupon-used (coupon-code uint))
  (if (is-valid coupon-code)
    (ok (default-to true (get used (map-get? coupons {coupon-code: coupon-code}))))
    err-invalid-code
  )
)

;; use coupon
(define-public (use-coupon (coupon-code uint))
  (if (is-owner tx-sender coupon-code)
    (match (map-get? coupons {coupon-code: coupon-code})
      code (if (get used code)
        err-code-used
          (begin
            (map-set coupons
              ((coupon-code coupon-code))
              ((discount u9) (used true))
            )
            (ok 1)
          )
        )
      err-invalid-code
    )
    err-cannot-use
  )
)

;; Only coupon owner can transfer it to other
(define-public (transfer (coupon-code uint) (receiver principal))
  (if
    (and
      (is-owner tx-sender coupon-code)
      (not (is-eq receiver tx-sender))
      (unwrap-panic (nft-transfer? coupon coupon-code tx-sender receiver))
    )
    (ok coupon-code)
    err-transfer-failed
  )
)