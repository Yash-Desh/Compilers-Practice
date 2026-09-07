; ModuleID = 'loop.cpp'
source_filename = "loop.cpp"
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu"

; Function Attrs: mustprogress nofree norecurse nosync nounwind memory(argmem: readwrite) uwtable
define dso_local void @_Z4foo1Pfi(ptr nocapture noundef %0, i32 noundef %1) local_unnamed_addr #0 {
  %3 = icmp sgt i32 %1, 0
  br i1 %3, label %4, label %62

4:                                                ; preds = %2
  %5 = zext nneg i32 %1 to i64
  %6 = icmp ult i32 %1, 8
  br i1 %6, label %60, label %7

7:                                                ; preds = %4
  %8 = and i64 %5, 2147483640
  br label %9

9:                                                ; preds = %55, %7
  %10 = phi i64 [ 0, %7 ], [ %56, %55 ]
  %11 = or disjoint i64 %10, 4
  %12 = getelementptr inbounds float, ptr %0, i64 %10
  %13 = getelementptr inbounds float, ptr %12, i64 4
  %14 = load <4 x float>, ptr %12, align 4, !tbaa !5
  %15 = load <4 x float>, ptr %13, align 4, !tbaa !5
  %16 = fcmp olt <4 x float> %14, zeroinitializer
  %17 = fcmp olt <4 x float> %15, zeroinitializer
  %18 = extractelement <4 x i1> %16, i64 0
  br i1 %18, label %19, label %21

19:                                               ; preds = %9
  %20 = getelementptr inbounds float, ptr %0, i64 %10
  store float 0.000000e+00, ptr %20, align 4, !tbaa !5
  br label %21

21:                                               ; preds = %19, %9
  %22 = extractelement <4 x i1> %16, i64 1
  br i1 %22, label %23, label %26

23:                                               ; preds = %21
  %24 = or disjoint i64 %10, 1
  %25 = getelementptr inbounds float, ptr %0, i64 %24
  store float 0.000000e+00, ptr %25, align 4, !tbaa !5
  br label %26

26:                                               ; preds = %23, %21
  %27 = extractelement <4 x i1> %16, i64 2
  br i1 %27, label %28, label %31

28:                                               ; preds = %26
  %29 = or disjoint i64 %10, 2
  %30 = getelementptr inbounds float, ptr %0, i64 %29
  store float 0.000000e+00, ptr %30, align 4, !tbaa !5
  br label %31

31:                                               ; preds = %28, %26
  %32 = extractelement <4 x i1> %16, i64 3
  br i1 %32, label %33, label %36

33:                                               ; preds = %31
  %34 = or disjoint i64 %10, 3
  %35 = getelementptr inbounds float, ptr %0, i64 %34
  store float 0.000000e+00, ptr %35, align 4, !tbaa !5
  br label %36

36:                                               ; preds = %33, %31
  %37 = extractelement <4 x i1> %17, i64 0
  br i1 %37, label %38, label %40

38:                                               ; preds = %36
  %39 = getelementptr inbounds float, ptr %0, i64 %11
  store float 0.000000e+00, ptr %39, align 4, !tbaa !5
  br label %40

40:                                               ; preds = %38, %36
  %41 = extractelement <4 x i1> %17, i64 1
  br i1 %41, label %42, label %45

42:                                               ; preds = %40
  %43 = or disjoint i64 %10, 5
  %44 = getelementptr inbounds float, ptr %0, i64 %43
  store float 0.000000e+00, ptr %44, align 4, !tbaa !5
  br label %45

45:                                               ; preds = %42, %40
  %46 = extractelement <4 x i1> %17, i64 2
  br i1 %46, label %47, label %50

47:                                               ; preds = %45
  %48 = or disjoint i64 %10, 6
  %49 = getelementptr inbounds float, ptr %0, i64 %48
  store float 0.000000e+00, ptr %49, align 4, !tbaa !5
  br label %50

50:                                               ; preds = %47, %45
  %51 = extractelement <4 x i1> %17, i64 3
  br i1 %51, label %52, label %55

52:                                               ; preds = %50
  %53 = or disjoint i64 %10, 7
  %54 = getelementptr inbounds float, ptr %0, i64 %53
  store float 0.000000e+00, ptr %54, align 4, !tbaa !5
  br label %55

55:                                               ; preds = %52, %50
  %56 = add nuw i64 %10, 8
  %57 = icmp eq i64 %56, %8
  br i1 %57, label %58, label %9, !llvm.loop !9

58:                                               ; preds = %55
  %59 = icmp eq i64 %8, %5
  br i1 %59, label %62, label %60

60:                                               ; preds = %4, %58
  %61 = phi i64 [ 0, %4 ], [ %8, %58 ]
  br label %63

62:                                               ; preds = %69, %58, %2
  ret void

63:                                               ; preds = %60, %69
  %64 = phi i64 [ %70, %69 ], [ %61, %60 ]
  %65 = getelementptr inbounds float, ptr %0, i64 %64
  %66 = load float, ptr %65, align 4, !tbaa !5
  %67 = fcmp olt float %66, 0.000000e+00
  br i1 %67, label %68, label %69

68:                                               ; preds = %63
  store float 0.000000e+00, ptr %65, align 4, !tbaa !5
  br label %69

69:                                               ; preds = %63, %68
  %70 = add nuw nsw i64 %64, 1
  %71 = icmp eq i64 %70, %5
  br i1 %71, label %62, label %63, !llvm.loop !13
}

attributes #0 = { mustprogress nofree norecurse nosync nounwind memory(argmem: readwrite) uwtable "min-legal-vector-width"="0" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cmov,+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "tune-cpu"="generic" }

!llvm.module.flags = !{!0, !1, !2, !3}
!llvm.ident = !{!4}

!0 = !{i32 1, !"wchar_size", i32 4}
!1 = !{i32 8, !"PIC Level", i32 2}
!2 = !{i32 7, !"PIE Level", i32 2}
!3 = !{i32 7, !"uwtable", i32 2}
!4 = !{!"Ubuntu clang version 18.1.3 (1ubuntu1)"}
!5 = !{!6, !6, i64 0}
!6 = !{!"float", !7, i64 0}
!7 = !{!"omnipotent char", !8, i64 0}
!8 = !{!"Simple C++ TBAA"}
!9 = distinct !{!9, !10, !11, !12}
!10 = !{!"llvm.loop.mustprogress"}
!11 = !{!"llvm.loop.isvectorized", i32 1}
!12 = !{!"llvm.loop.unroll.runtime.disable"}
!13 = distinct !{!13, !10, !12, !11}
