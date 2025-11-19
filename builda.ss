;;;; builda.ss - A quick Chez Scheme executable builder script.
;;;
;;; Copyright © 2025 CToID <funk443@icloud.com>
;;;
;;; This program is free software. It comes without any warranty, to the
;;; extent permitted by applicable law. You can redistribute it and/or
;;; modify it under the terms of the Do What The Fuck You Want To Public
;;; License, Version 2, as published by Sam Hocevar. See the COPYING file
;;; for more details.

(import (scheme))

;;; Main build configurations are set here.

(define entry-file
  ;; This content of this file should be something like this:
  ;;
  ;; ```scheme
  ;; (import (scheme))
  ;;
  ;; (define (main)
  ;;   (do-stuff))
  ;;
  ;; (scheme-program
  ;;   (lambda (fn . fns)
  ;;     (command-line (cons fn fns))
  ;;     (command-line-arguments fns)
  ;;     (main)))
  ;; ```
  "./s/main.ss")

(define build-directory "./build")

(define scheme-base-directory
  ;; This directory should contain `scheme.h`, `petite.boot`, `scheme.boot`,
  ;; and `libkernel.a` (or `libkernel.so`).
  ;;
  ;; If lz4 and zlib is not presented on your system library path, then `.so`
  ;; or `.a` files for these two libraries should also be presented in this
  ;; directory.
  "/usr/local/lib/csv10.3.0/a6le")

(define intermediate-filename "entry")

(define compile-command
  ;; List of commands for compiling the final executable.
  ;; Spaces are inserted between top-level forms, but not between the nested
  ;; lists.
  ;;
  ;; Only one level of nested lists can be used.
  ;;
  ;; Example:
  ;;
  ;; ```scheme
  ;; (define include-dir "/usr/local/include")
  ;; (list "gcc" "-O2"
  ;;       (list "-I" include-dir)
  ;;       "main.c")
  ;; ```
  ;;
  ;; The above form becomes `gcc -O2 -I/usr/local/include main.c`.
  (list "gcc"
        "-O2" "-omain"
        (list "-I" scheme-base-directory)
        (list build-directory (format "/~a.c" intermediate-filename))
        (list "-L" scheme-base-directory)
        (list "-l" "kernel")
        (list "-l" "lz4")
        (list "-l" "z")
        (list "-l" "curses")
        (list "-l" "m")))

;;; Internal stuffs - Compile and make scheme boot file.

(cond
  ((and (file-exists? build-directory) (file-directory? build-directory))
   (printf "INFO: Build files will be placed in ~s.~%" build-directory))
  ((file-exists? build-directory)
   (raise (condition
            (make-error)
            (make-message-condition "Cannot create build directory.")
            (make-irritants-condition (list build-directory)))))
  (else
   (mkdir build-directory)
   (printf "INFO: Made directory ~s.~%" build-directory)
   (printf "INFO: Build files will be placed in ~s.~%" build-directory)))

(compile-imported-libraries #t)
(generate-wpo-files #t)
(library-directories (cons (cons (path-parent entry-file) build-directory)
                           (library-directories)))

(compile-program entry-file (format "~a/~a.so"
                                    build-directory
                                    intermediate-filename))

(define libraries-without-wpo
  (compile-whole-program (format "~a/~a.wpo"
                                 build-directory
                                 intermediate-filename)
                         (format "~a/~a.wpo.so"
                                 build-directory
                                 intermediate-filename)))
(unless (null? libraries-without-wpo)
  (printf "WARNING: Cannot find the wpo files for these libraries:~%")
  (printf "|   ~{~s~%~}" libraries-without-wpo)
  (printf ".NOTE: These libraries will be loaded at the runtime, instead of being embedded."))

(make-boot-file (format "~a/~a.boot" build-directory intermediate-filename)
                '()
                (format "~a/petite.boot" scheme-base-directory)
                (format "~a/scheme.boot" scheme-base-directory)
                (format "~a/~a.wpo.so" build-directory intermediate-filename))

;;; Internal stuffs - Generate C file with embedded boot file content.

(define c-template
  (list "#include <scheme.h>"                                                            "\n"
        "#include <stddef.h>"                                                            "\n"
        "static unsigned char boot_content[] = {"                                        "\n"
        'boot-content                                                                    "\n"
        "};"                                                                             "\n"
        "static const iptr boot_length = " 'boot-length ";"                              "\n"
        "int main(int argc, const char *argv[]) {"                                       "\n"
        "    Sscheme_init(NULL);"                                                        "\n"
        "    Sregister_boot_file_bytes(\"main\", (void *) boot_content, boot_length);"   "\n"
        "    Sbuild_heap(NULL, NULL);"                                                   "\n"
        "    Scall1(Stop_level_value(Sstring_to_symbol(\"suppress-greeting\")), Strue);" "\n"
        "    int return_status = Sscheme_program(argv[0], argc, argv);"                  "\n"
        "    Sscheme_deinit();"                                                          "\n"
        "    return return_status;"                                                      "\n"
        "}" "\n"))

(define boot-content
  (call-with-port (open-file-input-port (format "~a/~a.boot"
                                                build-directory
                                                intermediate-filename)
                                        (file-options no-fail
                                                      no-create
                                                      no-truncate))
    (lambda (port)
      (let loop ((result '()))
        (define byte (get-u8 port))
        (if (eof-object? byte)
          (reverse result)
          (loop (cons byte result)))))))

(call-with-port (open-file-output-port (format "~a/~a.c"
                                               build-directory
                                               intermediate-filename)
                                       (file-options no-fail)
                                       (buffer-mode line)
                                       (make-transcoder (utf-8-codec)))
  (lambda (port)
    (let loop ((head c-template))
      (cond
        ((null? head)
         #t)
        ((string? (car head))
         (put-string port (car head))
         (loop (cdr head)))
        ((eq? 'boot-content (car head))
         (let print-block ((boot-head boot-content)
                           (col 0))
           (cond
             ((null? boot-head)
              #t)
             ((>= col 10)
              (put-string port ",\n")
              (print-block boot-head 0))
             ((zero? col)
              (put-string port "    ")
              (fprintf port "0x~2,'0x" (car boot-head))
              (print-block (cdr boot-head) (add1 col)))
             (else
              (fprintf port ", 0x~2,'0x" (car boot-head))
              (print-block (cdr boot-head) (add1 col)))))
         (loop (cdr head)))
        ((eq? 'boot-length (car head))
         (fprintf port "~d" (length boot-content))
         (loop (cdr head)))
        (else
         ;; Should be unreachable.
         (assert #f))))))

;;; Internal stuffs - Compile the C file.

(define compile-command-string
  (apply string-append
         (reverse (fold-left (lambda (result s)
                               (cons* " "
                                      (if (pair? s) (apply string-append s) s)
                                      result))
                             '()
                             compile-command))))

(system compile-command-string)
