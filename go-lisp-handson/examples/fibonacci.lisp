; フィボナッチ数列を再帰で計算する例。
(define (fib n)
  (if (< n 2)
      n
      (+ (fib (- n 1)) (fib (- n 2)))))

(define (print-fib-upto n)
  (if (<= n 10)
      (begin
        (display (fib n))
        (display " ")
        (print-fib-upto (+ n 1)))
      (newline)))

(display "fib(0)..fib(10): ")
(print-fib-upto 0)
