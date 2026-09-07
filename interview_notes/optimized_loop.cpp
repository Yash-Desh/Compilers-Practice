void foo1(float *a, int n) {
    for (int i = 0; i < n; i++) {
        a[i] = (a[i] < 0.0f) ? 0.0f : a[i];
    }
}