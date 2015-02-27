; In this test we check how heuristics for complete unrolling work. We have
; three knobs:
;  1) -unroll-threshold
;  2) -unroll-absolute-threshold and
;  3) -unroll-percent-of-optimized-for-complete-unroll
;
; They control loop-unrolling according to the following rules:
;  * If size of unrolled loop exceeds the absoulte threshold, we don't unroll
;    this loop under any circumstances.
;  * If size of unrolled loop is below the '-unroll-threshold', then we'll
;    consider this loop as a very small one, and completely unroll it.
;  * If a loop size is between these two tresholds, we only do complete unroll
;    it if estimated number of potentially optimized instructions is high (we
;    specify the minimal percent of such instructions).

; In this particular test-case, complete unrolling will allow later
; optimizations to remove ~55% of the instructions, the loop body size is 9,
; and unrolled size is 65.

; RUN: opt < %s -S -loop-unroll -unroll-max-iteration-count-to-analyze=1000 -unroll-absolute-threshold=10  -unroll-threshold=10  -unroll-percent-of-optimized-for-complete-unroll=30 | FileCheck %s -check-prefix=TEST1
; RUN: opt < %s -S -loop-unroll -unroll-max-iteration-count-to-analyze=1000 -unroll-absolute-threshold=100 -unroll-threshold=10  -unroll-percent-of-optimized-for-complete-unroll=30 | FileCheck %s -check-prefix=TEST2
; RUN: opt < %s -S -loop-unroll -unroll-max-iteration-count-to-analyze=1000 -unroll-absolute-threshold=100 -unroll-threshold=10  -unroll-percent-of-optimized-for-complete-unroll=80 | FileCheck %s -check-prefix=TEST3
; RUN: opt < %s -S -loop-unroll -unroll-max-iteration-count-to-analyze=1000 -unroll-absolute-threshold=100 -unroll-threshold=100 -unroll-percent-of-optimized-for-complete-unroll=80 | FileCheck %s -check-prefix=TEST4

; If the absolute threshold is too low, or if we can't optimize away requested
; percent of instructions, we shouldn't unroll:
; TEST1: %array_const_idx = getelementptr inbounds [9 x i32], [9 x i32]* @known_constant, i64 0, i64 %iv
; TEST3: %array_const_idx = getelementptr inbounds [9 x i32], [9 x i32]* @known_constant, i64 0, i64 %iv

; Otherwise, we should:
; TEST2-NOT: %array_const_idx = getelementptr inbounds [9 x i32], [9 x i32]* @known_constant, i64 0, i64 %iv

; Also, we should unroll if the 'unroll-threshold' is big enough:
; TEST4-NOT: %array_const_idx = getelementptr inbounds [9 x i32], [9 x i32]* @known_constant, i64 0, i64 %iv

; And check that we don't crash when we're not allowed to do any analysis.
; RUN: opt < %s -loop-unroll -unroll-max-iteration-count-to-analyze=0 -disable-output
target datalayout = "e-m:o-i64:64-f80:128-n8:16:32:64-S128"

@known_constant = internal unnamed_addr constant [9 x i32] [i32 0, i32 -1, i32 0, i32 -1, i32 5, i32 -1, i32 0, i32 -1, i32 0], align 16

define i32 @foo(i32* noalias nocapture readonly %src) {
entry:
  br label %loop

loop:                                                ; preds = %loop, %entry
  %iv = phi i64 [ 0, %entry ], [ %inc, %loop ]
  %r  = phi i32 [ 0, %entry ], [ %add, %loop ]
  %arrayidx = getelementptr inbounds i32, i32* %src, i64 %iv
  %src_element = load i32* %arrayidx, align 4
  %array_const_idx = getelementptr inbounds [9 x i32], [9 x i32]* @known_constant, i64 0, i64 %iv
  %const_array_element = load i32* %array_const_idx, align 4
  %mul = mul nsw i32 %src_element, %const_array_element
  %add = add nsw i32 %mul, %r
  %inc = add nuw nsw i64 %iv, 1
  %exitcond86.i = icmp eq i64 %inc, 9
  br i1 %exitcond86.i, label %loop.end, label %loop

loop.end:                                            ; preds = %loop
  %r.lcssa = phi i32 [ %r, %loop ]
  ret i32 %r.lcssa
}
