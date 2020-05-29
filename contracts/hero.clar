(define-non-fungible-token hero uint)

;; Constants
(define-constant hero-creator 'SPJWC5BA1SSWM9BG7SAMMBVNTB6E3PAMWG6SAG41)

;; Error
(define-constant err-only-creator u1)
(define-constant err-mint-failed u2)
(define-constant err-hero-not-exist u3)
(define-constant err-transfer-failed u4)
(define-constant err-only-hero-owner u5)
(define-constant err-invalid-offer-key u6)
(define-constant err-payment-failed u7)

;; Variables
(define-data-var next-id uint u1)

(define-map heroes
  ((hero-id uint))
  ( (name (buff 20))
    (atk uint)
    (hp uint)
  )
)

(define-map offers
  ((buyer principal) (hero-id uint) (coupon-code uint))
  ((price uint))
)

;; get owner of a hero
(define-read-only (owner-of? (hero-id uint))
  (nft-get-owner? hero hero-id)
)

;; The hero-creator craft a hero to owner
(define-public (craft-hero-for (owner principal) (name (buff 20)) (atk uint) (hp uint))
  (if (is-eq tx-sender hero-creator)
    (let ((hero-id (var-get next-id)))
      (if (is-ok (nft-mint? hero hero-id owner))
        (begin
          (map-set heroes
            {hero-id: hero-id}
            {
              name: name,
              atk: atk,
              hp: hp,
            }
          )
          (var-set next-id (+ hero-id u1))
          (ok hero-id)
        )
        (err err-mint-failed)
      )
    )
    (err err-only-creator)
  )
)

;; By default, crafted hero belongs to the hero-creator
(define-public (craft-hero (name (buff 20)) (atk uint) (hp uint) (price uint))
  (craft-hero-for hero-creator name atk hp)
)

;; When 2 heroes fight, the damage = opponent-atk - my-hp
;; if opponent-atk is higher than my-hp, my-hp will be deacreased to 0
;; the higher remain hp, the winner
;; if both are death, result is u0 - DRAW
(define-public (fight (hero-id1 uint) (hero-id2 uint))
  (let
    (
      (atk1 (default-to u0 (get atk (map-get? heroes {hero-id: hero-id1}))))
      (hp1 (default-to u0 (get hp (map-get? heroes {hero-id: hero-id1}))))
      (atk2 (default-to u0 (get atk (map-get? heroes {hero-id: hero-id2}))))
      (hp2 (default-to u0 (get hp (map-get? heroes {hero-id: hero-id2}))))
    )
    (begin
      (let
        (
          (remain-hp1
            (if (>= hp1 atk2) (- hp1 atk2) u0)
          )
          (remain-hp2
            (if (>= hp2 atk1) (- hp2 atk1) u0)
          )
        )
        (if (> remain-hp1 remain-hp2)
          (ok hero-id1)
          (if (> remain-hp2 remain-hp1)
            (ok hero-id2)
            (ok u0)
          )
        )
      )
    )
  )
)

;; Only hero owner can transfer it to other
(define-public (transfer (hero-id uint) (new-owner principal))
  (let ((hero-owner (unwrap! (owner-of? hero-id) (err err-hero-not-exist))))
    (if (is-eq hero-owner tx-sender)
      (match (nft-transfer? hero hero-id hero-owner new-owner)
        success (ok 1)
        error (err err-transfer-failed)
      )
      (err err-only-hero-owner)
    )
  )
)

;; bid to buy hero
(define-public (bid-with-coupon (hero-id uint) (price uint) (coupon-code uint))
  (ok (map-insert offers {buyer: tx-sender, hero-id: hero-id, coupon-code: coupon-code} {price: price}))
)

;; accep-bid
(define-public (accept-bid-with-coupon (hero-id uint) (buyer principal) (coupon-code uint))
  (let ((hero-owner (unwrap! (owner-of? hero-id) (err err-hero-not-exist))))
    (if (is-eq hero-owner tx-sender)
      (match (map-get? offers {buyer: buyer, hero-id: hero-id, coupon-code: coupon-code})
        offer (if (is-eq coupon-code u0)
          (match (stx-transfer? (get price offer) buyer tx-sender)
            success
            (begin
              (transfer hero-id buyer)
              (map-delete offers {buyer: buyer, hero-id: hero-id, coupon-code: coupon-code})
              (ok true)
            )
            error (err err-payment-failed)
          )
          (let ((discount-price (- (get price offer) (unwrap! (contract-call? coupon use-coupon coupon-code) u0))))
            (match (stx-transfer? discount-price buyer tx-sender)
              success (begin
                (transfer hero-id buyer)
                (map-delete offers {buyer: buyer, hero-id: hero-id, coupon-code: coupon-code})
                (ok true)
              )
              error (err err-payment-failed)
            )
          )
        )
        (err err-invalid-offer-key)
      )
      (err err-only-hero-owner)
    )
  )
)

;; bid to buy hero
(define-public (bid (hero-id uint) (price uint))
  (bid-with-coupon hero-id price u0)
)

;; accep-bid
(define-public (accept-bid (hero-id uint) (buyer principal))
  (accept-bid-with-coupon hero-id buyer u0)
)

