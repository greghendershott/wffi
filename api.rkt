#lang racket

(require "split.rkt"
         )

(provide (struct-out api)
         )


(struct api
        (name            ;string?
         desc            ;string?
         req             ;string?
         resp            ;string?
         route-px        ;pregexp?
        ) #:transparent)
