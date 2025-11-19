(library (lib2 util)
  (export say-hello)
  (import (scheme))

  (define (say-hello)
    (display "hello from scheme")))
