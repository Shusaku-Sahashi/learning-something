; 階乗を再帰で計算する例。
(define (fact n)
  (if (= n 0)
      1
      (* n (fact (- n 1)))))

(display "5! = ")
(display (fact 5))
(newline)

(display "10! = ")
(display (fact 10))
(newline)
