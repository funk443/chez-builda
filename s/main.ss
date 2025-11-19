(import (scheme)
        (lib1))

(define (main)
  (hello))

(scheme-program
  (lambda (fn . fns)
    (command-line (cons fn fns))
    (command-line-arguments fns)
    (main)))
