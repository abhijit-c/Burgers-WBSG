function burgers_wbsg(u0_h, b_h, E, T, dx, dt)
# burgers_wbsg.jl solves the Burgers equation 
# \[
#   u_t(x,t,z) + f_x(u(x,t,z)) = -b'(x,z)u(x,t,z), (*)
#   u(x,0) = u0(x),
#   u(0,t) = 2.
# \] 
# in space (x) and time (t) given some source term $-b'(x,z)u(t,x)$ where $z$ is
# some user specified random variable and $f(u) = u^2/2$. The random input is
# expanded with the generalized polynomial chaos (gPC) setting:
# \begin{align*}
#   u(x,t,z) &= u_N(x,t,z) = \sum_{m=1}^M \hat{u}_m(x,t)\Phi_m(z) \\
#   b(x,z)   &= b_N(x,z)   = \sum_{m=1}^M \hat{b}_m(x,t)\Phi_m(z) \\
# \end{align*}
# where $(\Phi_m)_{m=1}^M$ is a collection of orthogonal polynomials chosen with
# respect to the distribution zn obeys.
# ------------------------------------------------------------------------------
# Parameter List:
# u0_h : M x N matrix where the jth column corresponds to the cell average of
#        the initial condition over the jth spatial cell expanded out in the
#        orthogonal polynomial basis corresponding to z, i.e.:
#        \[
#          avg(u0(x_j)) \approx \sum_{m=1}^M u0_h(m,j) polyval(Phi{m},x_j)
#        \]
# b_h : M x N matrix where the jth column corresponds to the cell average of the
#       initial condition over the jth spatial cell expanded out in the
#       orthogonal polynomial basis corresponding to z, i.e.:
#       \[
#         avg(b(x_j)) \approx \sum_{m=1}^M b_h(m,j) polyval(Phi{m},x_j)
#       \]
# E : M x M x M matrix where $E(k,m,n) = Expectation[\Phi_k \Phi_m \Phi_n]$,
#     where $(\Phi_m)_{m=1}^M$ is the orthogonal polynomial basis descibed
#     earlier, and the expectation is with respect to the law z obeys.
# T : Final time to solve (*) up to.
# dx : Parameter controlling width of spatial discretization.
# dt : Parameter controlling width of temporal discretization.
# Returned Variables:
# u_hat: Coefficients of u in its generalized polynomial chaos expansion in the
#        provided set of orthogonal polynomials
# ------------------------------------------------------------------------------
# Authors: Andrew Shedlock & Abhijit Chowdhary, @ North Carolina State.
# Date  : 2022/04/14
  
  M, N = size(u0_h);
  B = zeros(M,M,N);
  for j=1:N
    B[:, :, j] = build_Bj(E, b_h[:, j]);
  end

  u_h = u0_h;
  curr_t = 0.0;
  u_hj_prev = zeros(M);
  Aj_prev = zeros(M,M);
  while curr_t < T
    u_hj_prev = u_h[:, 1];
    Aj_prev = build_Aj(E, u_hj_prev);
    for j=2:N #For each spatial point, update gPC coefficients
      @views u_hj = u_h[:, j];
      Aj = build_Aj(E, u_hj);

      @views Bj = B[:,:,j]; 
      @views Bj_prev = B[:,:,j-1];

      rhs = -( Aj*u_hj - Aj_prev*u_hj_prev ) / (2*dx);
      rhs = rhs .- ( Bj-Bj_prev )*( u_hj + u_hj_prev ) / (2*dx);

      u_hj_prev = u_hj;
      Aj_prev = Aj;
      u_h[:,j] = u_hj .+ dt*rhs;
    end
    curr_t = curr_t + dt;
  end
  return u_h
end

function build_Aj(E, u_hj)
  M = size(E,1);
  Aj = zeros(M,M);
  for m=1:M
    for n=m:M
      @views Aj[m,n] = dot(u_hj, E[:,m,n]);
      Aj[n,m] = Aj[m,n];
    end
  end
  return Aj
end

function build_Bj(E, b_hj)
  M = size(E,1);
  Bj = zeros(M, M);
  for m=1:M
    for n=m:M
      @views Bj[m,n] = dot(b_hj, E[:,m,n]);
      Bj[n,m] = Bj[m,n];
    end
  end
  return Bj
end
