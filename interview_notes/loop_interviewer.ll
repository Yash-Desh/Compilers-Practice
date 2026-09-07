define dso_local void @foo1(float*, int)(ptr nofree noundef captures(none) %a, i32 noundef %n) local_unnamed_addr {
entry:
  %cmp8 = icmp sgt i32 %n, 0
  br i1 %cmp8, label %for.body.preheader, label %for.cond.cleanup

for.body.preheader:
  %wide.trip.count = zext nneg i32 %n to i64
  %min.iters.check = icmp ult i32 %n, 8
  br i1 %min.iters.check, label %for.body.preheader26, label %vector.ph

vector.ph:
  %n.vec = and i64 %wide.trip.count, 2147483640
  br label %vector.body

vector.body:
  %index = phi i64 [ 0, %vector.ph ], [ %index.next, %pred.store.continue25 ]
  %0 = getelementptr inbounds nuw [4 x i8], ptr %a, i64 %index
  %1 = getelementptr inbounds nuw i8, ptr %0, i64 16
  %wide.load = load <4 x float>, ptr %0, align 4
  %wide.load11 = load <4 x float>, ptr %1, align 4
  %2 = fcmp olt <4 x float> %wide.load, zeroinitializer
  %3 = fcmp olt <4 x float> %wide.load11, zeroinitializer
  %4 = extractelement <4 x i1> %2, i64 0
  br i1 %4, label %pred.store.if, label %pred.store.continue

pred.store.if:
  store float 0.000000e+00, ptr %0, align 4
  br label %pred.store.continue

pred.store.continue:
  %5 = extractelement <4 x i1> %2, i64 1
  br i1 %5, label %pred.store.if12, label %pred.store.continue13

pred.store.if12:
  %6 = getelementptr inbounds nuw [4 x i8], ptr %a, i64 %index
  %7 = getelementptr inbounds nuw i8, ptr %6, i64 4
  store float 0.000000e+00, ptr %7, align 4
  br label %pred.store.continue13

pred.store.continue13:
  %8 = extractelement <4 x i1> %2, i64 2
  br i1 %8, label %pred.store.if14, label %pred.store.continue15

pred.store.if14:
  %9 = getelementptr inbounds nuw [4 x i8], ptr %a, i64 %index
  %10 = getelementptr inbounds nuw i8, ptr %9, i64 8
  store float 0.000000e+00, ptr %10, align 4
  br label %pred.store.continue15

pred.store.continue15:
  %11 = extractelement <4 x i1> %2, i64 3
  br i1 %11, label %pred.store.if16, label %pred.store.continue17

pred.store.if16:
  %12 = getelementptr inbounds nuw [4 x i8], ptr %a, i64 %index
  %13 = getelementptr inbounds nuw i8, ptr %12, i64 12
  store float 0.000000e+00, ptr %13, align 4
  br label %pred.store.continue17

pred.store.continue17:
  %14 = extractelement <4 x i1> %3, i64 0
  br i1 %14, label %pred.store.if18, label %pred.store.continue19

pred.store.if18:
  %15 = getelementptr inbounds nuw [4 x i8], ptr %a, i64 %index
  %16 = getelementptr inbounds nuw i8, ptr %15, i64 16
  store float 0.000000e+00, ptr %16, align 4
  br label %pred.store.continue19

pred.store.continue19:
  %17 = extractelement <4 x i1> %3, i64 1
  br i1 %17, label %pred.store.if20, label %pred.store.continue21

pred.store.if20:
  %18 = getelementptr inbounds nuw [4 x i8], ptr %a, i64 %index
  %19 = getelementptr inbounds nuw i8, ptr %18, i64 20
  store float 0.000000e+00, ptr %19, align 4
  br label %pred.store.continue21

pred.store.continue21:
  %20 = extractelement <4 x i1> %3, i64 2
  br i1 %20, label %pred.store.if22, label %pred.store.continue23

pred.store.if22:
  %21 = getelementptr inbounds nuw [4 x i8], ptr %a, i64 %index
  %22 = getelementptr inbounds nuw i8, ptr %21, i64 24
  store float 0.000000e+00, ptr %22, align 4
  br label %pred.store.continue23

pred.store.continue23:
  %23 = extractelement <4 x i1> %3, i64 3
  br i1 %23, label %pred.store.if24, label %pred.store.continue25

pred.store.if24:
  %24 = getelementptr inbounds nuw [4 x i8], ptr %a, i64 %index
  %25 = getelementptr inbounds nuw i8, ptr %24, i64 28
  store float 0.000000e+00, ptr %25, align 4
  br label %pred.store.continue25

pred.store.continue25:
  %index.next = add nuw i64 %index, 8
  %26 = icmp eq i64 %index.next, %n.vec
  br i1 %26, label %middle.block, label %vector.body

middle.block:
  %cmp.n = icmp eq i64 %n.vec, %wide.trip.count
  br i1 %cmp.n, label %for.cond.cleanup, label %for.body.preheader26

for.body.preheader26:
  %indvars.iv.ph = phi i64 [ 0, %for.body.preheader ], [ %n.vec, %middle.block ]
  br label %for.body

for.cond.cleanup:
  ret void

for.body:
  %indvars.iv = phi i64 [ %indvars.iv.next, %for.inc ], [ %indvars.iv.ph, %for.body.preheader26 ]
  %arrayidx = getelementptr inbounds nuw [4 x i8], ptr %a, i64 %indvars.iv
  %27 = load float, ptr %arrayidx, align 4
  %cmp1 = fcmp olt float %27, 0.000000e+00
  br i1 %cmp1, label %if.then, label %for.inc

if.then:
  store float 0.000000e+00, ptr %arrayidx, align 4
  br label %for.inc

for.inc:
  %indvars.iv.next = add nuw nsw i64 %indvars.iv, 1
  %exitcond.not = icmp eq i64 %indvars.iv.next, %wide.trip.count
  br i1 %exitcond.not, label %for.cond.cleanup, label %for.body
}
