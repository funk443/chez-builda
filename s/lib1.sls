(library (lib1)
  (export hello)
  (import (scheme)
          (lib2 util))

  (define (hello)
    (say-hello)
    (newline)))
