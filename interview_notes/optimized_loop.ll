
define dso_local void @foo1(float*, int)(ptr nocapture noundef %a, i32 noundef %n) local_unnamed_addr {
entry:
  %cmp12 = icmp sgt i32 %n, 0
  br i1 %cmp12, label %for.body.preheader, label %for.cond.cleanup

for.body.preheader:
  %wide.trip.count = zext nneg i32 %n to i64
  %min.iters.check = icmp ult i32 %n, 8
  br i1 %min.iters.check, label %for.body.preheader16, label %vector.ph

vector.ph:
  %n.vec = and i64 %wide.trip.count, 2147483640
  br label %vector.body

vector.body:
  %index = phi i64 [ 0, %vector.ph ], [ %index.next, %vector.body ]
  %0 = getelementptr inbounds float, ptr %a, i64 %index
  %1 = getelementptr inbounds float, ptr %0, i64 4
  %wide.load = load <4 x float>, ptr %0, align 4
  %wide.load15 = load <4 x float>, ptr %1, align 4
  %2 = fcmp olt <4 x float> %wide.load, zeroinitializer
  %3 = fcmp olt <4 x float> %wide.load15, zeroinitializer
  %4 = select <4 x i1> %2, <4 x float> zeroinitializer, <4 x float> %wide.load
  %5 = select <4 x i1> %3, <4 x float> zeroinitializer, <4 x float> %wide.load15
  store <4 x float> %4, ptr %0, align 4
  store <4 x float> %5, ptr %1, align 4
  %index.next = add nuw i64 %index, 8
  %6 = icmp eq i64 %index.next, %n.vec
  br i1 %6, label %middle.block, label %vector.body

middle.block:
  %cmp.n = icmp eq i64 %n.vec, %wide.trip.count
  br i1 %cmp.n, label %for.cond.cleanup, label %for.body.preheader16

for.body.preheader16:
  %indvars.iv.ph = phi i64 [ 0, %for.body.preheader ], [ %n.vec, %middle.block ]
  br label %for.body

for.cond.cleanup:
  ret void

for.body:
  %indvars.iv = phi i64 [ %indvars.iv.next, %for.body ], [ %indvars.iv.ph, %for.body.preheader16 ]
  %arrayidx = getelementptr inbounds float, ptr %a, i64 %indvars.iv
  %7 = load float, ptr %arrayidx, align 4
  %cmp1 = fcmp olt float %7, 0.000000e+00
  %cond = select i1 %cmp1, float 0.000000e+00, float %7
  store float %cond, ptr %arrayidx, align 4
  %indvars.iv.next = add nuw nsw i64 %indvars.iv, 1
  %exitcond.not = icmp eq i64 %indvars.iv.next, %wide.trip.count
  br i1 %exitcond.not, label %for.cond.cleanup, label %for.body
}

