; クロージャとリスト操作を組み合わせた例。
(define (make-counter)
  (let ((count 0))
    (lambda ()
      (set! count (+ count 1))
      count)))

(define counter (make-counter))
(display (counter)) (display " ")
(display (counter)) (display " ")
(display (counter))
(newline)

; map相当の処理を自分で書いてみる。
(define (my-map f lst)
  (if (null? lst)
      (list)
      (cons (f (car lst)) (my-map f (cdr lst)))))

(define (square x) (* x x))

(display (my-map square (list 1 2 3 4 5)))
(newline)
