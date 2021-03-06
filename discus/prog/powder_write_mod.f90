MODULE powder_write_mod
!
USE errlist_mod 
!
IMPLICIT NONE
!
PUBLIC
!
CONTAINS
!
      SUBROUTINE powder_out (value)
!-                                                                      
!     Write the powder pattern                                          
!+                                                                      
      USE discus_config_mod 
      USE debye_mod 
      USE diffuse_mod 
      USE output_mod 
      USE powder_mod 
      USE powder_tables_mod
      USE wink_mod
      USE precision_mod
      USE trig_degree_mod
      IMPLICIT none 
!                                                                       
!     INTEGER, PARAMETER :: iff = 2 
!                                                                       
      INTEGER, INTENT(IN) :: value ! Type of output
!                                                                       
      INTEGER ii, j , iii, jstart
      INTEGER   :: all_status  ! Allocation status
      INTEGER   :: npkt        ! number of points in powder pattern
      INTEGER   :: npkt_equi   ! number of points in equidistant powder pattern
      INTEGER   :: npkt_wrt    ! number of points in powder pattern ready to write
      LOGICAL lread 
      REAL, DIMENSION(:), ALLOCATABLE :: pow_tmp  ! Local temporary copy of intensities
      REAL, DIMENSION(:), ALLOCATABLE :: xpl  ! x-values of calculated powder pattern
      REAL, DIMENSION(:), ALLOCATABLE :: ypl  ! y-values of calculated powder pattern
      REAL, DIMENSION(:), ALLOCATABLE :: y2a  ! y-values of splined    powder pattern
      REAL, DIMENSION(:), ALLOCATABLE :: xwrt ! x-values of powder pattern ready for output
      REAL, DIMENSION(:), ALLOCATABLE :: ywrt ! y-values of powder pattern ready for output
      REAL :: ttheta, lp=1.0
      REAL ss, st 
      REAL :: q=0.0, stl=0.0, dstar=0.0
      REAL      :: normalizer
      REAL xmin, xmax, xdel , xpos, xxmax
      REAL (PREC_DP)     :: xstart  ! qmin  for sin Theta / lambda calculation
      REAL (PREC_DP)     :: xdelta  ! qstep for sin Theta / lambda calculation
      REAL      :: xequ    ! x-position of equdistant curve
      REAL      :: yequ    ! y-value    of equdistant curve
      REAL      :: tthmin  ! minimum for equdistant curve
      REAL      :: tthmax  ! minimum for equdistant curve
      REAL      ::   qmin  ! minimum for equdistant curve
      REAL      ::   qmax  ! minimum for equdistant curve
      REAL      :: arg
      REAL      :: pow_tmp_sum = 0.0
      REAL      :: pow_uuu_sum = 0.0
!                                                                       
!      REAL lorentz 
!      REAL polarisation 
!      REAL sind, asind 
!
!
      IF(.NOT. (value == 1 .or. value == 7 .or. value == 8 .or. &
                value == 9 .or. value == 10                )) THEN
         ier_msg(1) = ' Powder output is defined only for:'
         ier_msg(2) = ' Intensity, S(Q), F(Q), <f>^2, <f^2>'
         ier_msg(3) = ' '
         ier_num = -124
         ier_typ = ER_APPL
         RETURN
      ENDIF
!
      ALLOCATE(pow_tmp(0:POW_MAXPKT),stat = all_status)  ! Allocate array for powder pattern copy
      ALLOCATE(xpl(0:POW_MAXPKT),stat = all_status)  ! Allocate array for calculated powder pattern
      ALLOCATE(ypl(0:POW_MAXPKT),stat = all_status)  ! Allocate array for calculated powder pattern
      pow_tmp = 0.0
      xpl     = 0.0
      ypl     = 0.0
!                                                                       
      IF (pow_four_type.eq.POW_COMPL.or.pow_four_type.eq.POW_NEW) THEN 
         IF (pow_axis.eq.POW_AXIS_Q) THEN 
            xmin = pow_qmin 
            xmax = pow_qmax 
            xdel = pow_deltaq 
         ELSEIF (pow_axis.eq.POW_AXIS_TTH) THEN 
            xmin = pow_tthmin 
            xmax = pow_tthmax 
            xdel = pow_deltatth 
         ELSE 
            ier_num = - 104 
            ier_typ = ER_APPL 
            ier_msg (1) = 'Use command ==> set axis,{"tth"|"q"}' 
            ier_msg (2) = 'within the powder menu to define the axis' 
            ier_msg (3) = ' ' 
            DEALLOCATE(pow_tmp,stat = all_status)  ! DeAllocate array for powder pattern copy
            DEALLOCATE(xpl    ,stat = all_status)  ! DeAllocate array for calculated powder pattern
            DEALLOCATE(ypl    ,stat = all_status)  ! DeAllocate array for calculated powder pattern
            RETURN 
         ENDIF 
         npkt = MIN(NINT((xmax+xdel-xmin)/xdel) + 2, POW_MAXPKT)
      ELSEIF (pow_four_type.eq.POW_HIST ) THEN
         IF (pow_axis.eq.POW_AXIS_Q) THEN 
            xmin = pow_qmin 
            xmax = pow_qmax 
            xdel = (pow_qmax - pow_qmin) / (num (1) ) 
         ELSEIF (pow_axis.eq.POW_AXIS_TTH) THEN 
            xmin = pow_tthmin 
            xmax = pow_tthmax 
            xdel = (pow_tthmax - pow_tthmin) / (num (1) ) 
         ELSE 
            ier_num = - 104 
            ier_typ = ER_APPL 
            ier_msg (1) = 'Use command ==> set axis,{"tth"|"q"}' 
            ier_msg (2) = 'within the powder menu to define the axis' 
            ier_msg (3) = ' ' 
            DEALLOCATE(pow_tmp,stat = all_status)  ! DeAllocate array for powder pattern copy
            DEALLOCATE(xpl    ,stat = all_status)  ! DeAllocate array for calculated powder pattern
            DEALLOCATE(ypl    ,stat = all_status)  ! DeAllocate array for calculated powder pattern
            RETURN 
         ENDIF 
         npkt = MIN(num(1), POW_MAXPKT)
      ENDIF 
!
!     Prepare average form factors for S(Q) or F(Q), or faver2, f2aver
!
      IF(value == 7 .or. value == 8  .or.        &
         value == 9 .or. value == 10      ) THEN
         IF (pow_axis.eq.POW_AXIS_Q) THEN 
            IF(.NOT.(pow_four_mode == POW_STACK)) THEN  ! Stack did its own faver2
               IF (pow_four_type.eq.POW_COMPL) THEN     ! Need to initialize pow_istl
                  xstart = pow_qmin  /zpi
                  xdelta = pow_deltaq/zpi
                  CALL powder_stltab(npkt,xstart,xdelta) ! Really only needed for <f^2> and <f>^2 for F(Q) and S(Q)
               ENDIF
               CALL powder_f2aver (npkt   )             ! Calculate average form factors <f>2 and <f^2>
            ENDIF
         ELSE                                           ! F(Q) works for Q-axis only
            ier_msg (1) = 'Use command ==> form, powder,q'
            ier_msg (2) = 'within the output menu to define the axis' 
            ier_num = -125
            ier_typ = ER_APPL
            DEALLOCATE(pow_tmp,stat = all_status)  ! DeAllocate array for powder pattern copy
            DEALLOCATE(xpl    ,stat = all_status)  ! DeAllocate array for calculated powder pattern
            DEALLOCATE(ypl    ,stat = all_status)  ! DeAllocate array for calculated powder pattern
            RETURN
        ENDIF
      ENDIF
!
      lread = .false. 
      IF (ier_num /= 0) THEN 
         DEALLOCATE(pow_tmp,stat = all_status)  ! DeAllocate array for powder pattern copy
         DEALLOCATE(xpl    ,stat = all_status)  ! DeAllocate array for calculated powder pattern
         DEALLOCATE(ypl    ,stat = all_status)  ! DeAllocate array for calculated powder pattern
         RETURN
      ENDIF
      IF(value == 9) THEN          ! Output is f^2 aver
         DO j = 1, npkt
            pow_tmp (j-1) = REAL(pow_f2aver(j))
         ENDDO
      ELSEIF(value == 10) THEN     ! Output is faver^2 
         DO j = 1, npkt
            pow_tmp (j-1) = REAL(pow_faver2(j))
         ENDDO
      ELSE                         ! All other output
         IF (pow_four_type.ne.POW_COMPL) THEN 
!                                                                       
!     This is a Debye calculation, copy rsf or csf into pow_tmp         
!                                                                       
            IF (pow_four_type.eq.POW_DEBYE) THEN 
               IF (npkt    .le.POW_MAXPKT) THEN 
                  DO j = 1, npkt    
                     pow_tmp (j) = REAL (csf (j) )    ! Double precision no longer needed
                  ENDDO 
               ENDIF 
            ELSEIF(pow_four_type.eq.POW_FAST.or.pow_four_type.eq.POW_HIST) THEN
               IF (npkt    .le.POW_MAXPKT) THEN 
                  DO j = 1, npkt    
                     pow_tmp (j) = REAL(rsf (j) )     ! Double precision no longer needed
                  ENDDO 
               ENDIF 
            ENDIF 
         ELSE
            pow_tmp(:) = REAL(pow_qsp(:))   ! Double precision no longer needed
         ENDIF 
!                                                                       
!- -Does the powder pattern have to be convoluted by a profile function?
!                                                                       
         IF (pow_profile.eq.POW_PROFILE_GAUSS) THEN 
            IF (pow_delta.gt.0.0) THEN 
               xxmax = xmax + xdel
               CALL powder_conv_res (pow_tmp, xmin,xxmax, xdel,         &
               pow_delta, POW_MAXPKT)                                    
            ENDIF 
         ELSEIF (pow_profile.eq.POW_PROFILE_PSVGT) THEN 
           IF (pow_u.ne.0.0.or.pow_v.ne.0.0.or.pow_etax.ne.0.0.or.      &
               pow_p1.ne.0.0.or.pow_p2.ne.0.0.or.pow_p3.ne.0.0.or.      &
               pow_p4.ne.0.0                                      ) THEN       
               xxmax = xmax + xdel
               CALL powder_conv_psvgt_uvw (pow_tmp, xmin,xxmax, xdel,   &
               pow_eta, pow_etax, pow_u, pow_v, pow_w, pow_p1, pow_p2,  &
               pow_p3, pow_p4, pow_width, POW_MAXPKT)
            ELSE 
               xxmax = xmax + xdel
               CALL powder_conv_psvgt_fix (pow_tmp, xmin,xxmax, xdel,   &
               pow_eta, pow_w, pow_width, POW_MAXPKT)
            ENDIF 
         ENDIF 
      ENDIF           ! Output is if_block if(value==9)
!                                                                       
!------ copy the powder pattern into output array, if necessary this will be put on
!       equidistant scale
!                                                                       
      IF (pow_four_type.eq.POW_COMPL.or.pow_four_type.eq.POW_NEW) THEN                                                           
         DO ii = 0, npkt - 1
            iii = ii + 1
            xpos = ii * xdel + xmin 
            IF (pow_axis.eq.POW_AXIS_Q) THEN 
               q      = xpos
               dstar  = q / zpi
               stl    = q / zpi / 2.
               ttheta = 2.*asind ( REAL(q / 2. /zpi *rlambda ))
            ELSEIF (pow_axis.eq.POW_AXIS_TTH) THEN 
               ttheta = xpos
               stl    =            sind (ttheta * 0.5) / rlambda 
               dstar  = 2. *       sind (ttheta * 0.5) / rlambda 
               q      = 2. * zpi * sind (ttheta * 0.5) / rlambda 
            ENDIF 
            IF(value == 7 .or. value == 8)  THEN
               lp = lorentz(ttheta,1)
            ELSEIF(value == 9 .or. value == 10) THEN  ! f2aver or faver2
               lp = 1
            ELSE
               lp     = lorentz (ttheta,0) * polarisation (ttheta) 
            ENDIF 
            IF (cpow_form.eq.'tth') THEN 
               xpl(iii) = ttheta
            ELSEIF (cpow_form.eq.'stl') THEN 
               xpl(iii) = stl
            ELSEIF (cpow_form.eq.'q  ') THEN 
               xpl(iii) = q
            ELSEIF (cpow_form.eq.'dst') THEN 
               xpl(iii) = dstar
            ELSEIF (cpow_form.eq.'lop') THEN 
               xpl(iii) = ttheta
            ENDIF 
            ypl(iii) = pow_tmp(iii) * lp
         ENDDO 
      ELSEIF (pow_four_type.eq.POW_HIST) THEN 
         IF (pow_axis.eq.POW_AXIS_DSTAR) THEN 
         ELSEIF (pow_axis.eq.POW_AXIS_Q) THEN 
            xm(1)  = pow_qmin / zpi 
            ss     = pow_qmax / zpi 
            st     = (pow_qmax - pow_deltaq) / zpi 
            uin(1) = pow_deltaq / zpi 
         ELSEIF (pow_axis.eq.POW_AXIS_TTH) THEN 
            xm(1)  = 2 * sind (0.5 * pow_tthmin) / rlambda 
            ss     = 2 * sind (0.5 * pow_tthmax) / rlambda 
            st     = 2 * sind (0.5 * (pow_tthmax - pow_deltatth) ) / rlambda
            uin(1) = (ss - st) / 2. 
         ENDIF 
         DO ii = 1, npkt    
            dstar = (xm (1) + (ii - 1) * uin (1) ) 
            stl = .5 * (xm (1) + (ii - 1) * uin (1) ) 
            q = zpi * (xm (1) + (ii - 1) * uin (1) ) 
            ttheta = 2. * asind (dstar * rlambda / 2.) 
!
            IF(value == 7 .or. value == 8) THEN
               lp = 1                     ! For S(Q) and F(Q) nor Polarisation corr.
            ELSEIF(value == 9 .or. value == 10) THEN  ! f2aver or faver2
               lp = 1
            ELSE
               lp = polarisation (ttheta) 
            ENDIF
            IF (cpow_form.eq.'tth') THEN 
               xpl(ii) = ttheta
            ELSEIF (cpow_form.eq.'stl') THEN 
               xpl(ii) = stl
            ELSEIF (cpow_form.eq.'q  ') THEN 
               xpl(ii) = q
            ELSEIF (cpow_form.eq.'dst') THEN 
               xpl(ii) = dstar
            ENDIF 
            ypl(ii) = pow_tmp(ii) * lp
         ENDDO 
      ENDIF 
!
!     Prepare S(Q) or F(Q)
!
      IF(value == 7 .or. value == 8) THEN
         IF (pow_axis.eq.POW_AXIS_Q) THEN 
            pow_tmp_sum = 0.0                           ! Determine normalizer, such that 
            pow_uuu_sum = 0.0                           ! the average F(q) is 0.0
!           jstart = MAX(1,2-int(xmin/xdel))            ! Exclude q = 0
            jstart = MAX(1,int((1-xmin)/xdel)+1)        ! Exclude q < 1.0
            DO j = jstart, npkt
               q = ((j-1)*xdel + xmin)
               pow_tmp_sum = pow_tmp_sum + ypl(j)/REAL(pow_faver2(j))* q
               pow_uuu_sum = pow_uuu_sum       + exp(-q**2*pow_u2aver)*q
            ENDDO
            normalizer = pow_tmp_sum/pow_uuu_sum
!
            IF(value == 7) THEN                         ! Calc S(Q)
               DO j = 1, npkt   
                  q = ((j-1)*xdel + xmin)
                  ypl(j) =  (ypl(j)/REAL(pow_faver2(j))/normalizer   &
                            + 1.0 - exp(-q**2*pow_u2aver)) 
               ENDDO
            ELSE                                        ! Calc F(Q)
               DO j = 1, npkt   
                  q = ((j-1)*xdel + xmin)
                  ypl(j) =  (ypl(j)/REAL(pow_faver2(j))/normalizer   &
                                  - exp(-q**2*pow_u2aver)) * q
               ENDDO
            ENDIF
         ELSE                                           ! F(Q) works for Q-axis only
!           Should never occur, as covered by "prepare S(Q)" section
            ier_msg (1) = 'Use command ==> form, powder,q'
            ier_msg (2) = 'within the output menu to define the axis' 
            ier_num = -125
            ier_typ = ER_APPL
            DEALLOCATE(pow_tmp,stat = all_status)  ! DeAllocate array for powder pattern copy
            DEALLOCATE(xpl    ,stat = all_status)  ! DeAllocate array for calculated powder pattern
            DEALLOCATE(ypl    ,stat = all_status)  ! DeAllocate array for calculated powder pattern
            RETURN
         ENDIF                   ! pow_axis      == ??
      ENDIF   !Prepare S(Q), F(Q)
!
!
      IF( cpow_form == 'tth' ) THEN
         IF ( pow_axis      == POW_AXIS_Q  .or.  &        ! Non matching form, spline onto equidistant steps
              pow_four_type == POW_HIST            ) THEN ! DEBYE, always spline
            IF(out_user_limits) THEN                      ! User provided values
               pow_tthmin   = out_user_values(1)
               pow_tthmax   = out_user_values(2)
               pow_deltatth = out_user_values(3)
            ELSE                                          ! Convert q limits
               IF ( pow_axis == POW_AXIS_Q) THEN             ! Convert q limits to 2Theta
                  arg        = xmin/zpi * rlambda / 2.       ! Directly with arg in asind()
                  pow_tthmin = 2.*asind(arg)                 ! results in error ??????????
                  arg        = xmax/zpi * rlambda / 2.
                  pow_tthmax = 2.*asind(arg)
                  pow_deltatth = xpl(2)-xpl(1)
               ENDIF
            ENDIF
            IF(pow_tthmin < xpl(1) ) THEN                 ! User lower limit too low!
               tthmin =              (INT( (xpl(1)              )/pow_deltatth) + 1)*pow_deltatth
            ELSE
               tthmin = pow_tthmin
            ENDIF
            IF(pow_tthmax > xpl(npkt) ) THEN              ! User upper limit too high!
               tthmax =              (INT( (           xpl(npkt))/pow_deltatth) - 1)*pow_deltatth
            ELSE
               tthmax = pow_tthmax
            ENDIF
            xmin = tthmin                                  ! Adjust limits needed later to cut 
            xmax = tthmax                                  ! off rounding errors
            npkt_equi =     INT((tthmax-tthmin)/pow_deltatth) + 1             
            ALLOCATE(y2a (1:POW_MAXPKT),stat = all_status) ! Allocate array for calculated powder pattern
            ALLOCATE(xwrt(0:npkt_equi),stat = all_status)  ! Allocate array for powder pattern ready to write
            ALLOCATE(ywrt(0:npkt_equi),stat = all_status)  ! Allocate array for powder pattern ready to write
            xwrt = 0.0
            ywrt = 0.0
            y2a  = 0.0
            CALL spline (npkt, xpl, ypl, 1e31, 1e31, y2a)
            DO ii = 1, npkt_equi
               xequ = tthmin + (ii-1)*pow_deltatth
               CALL splint (npkt, xpl, ypl, y2a, xequ, yequ)
               IF(ier_num/=0) THEN
                  DEALLOCATE( pow_tmp, stat = all_status)
                  DEALLOCATE( xpl, stat = all_status)
                  DEALLOCATE( ypl, stat = all_status)
                  DEALLOCATE( y2a, stat = all_status)
                  DEALLOCATE( xwrt, stat = all_status)
                  DEALLOCATE( ywrt, stat = all_status)
                  RETURN
               ENDIF
               xwrt(ii) = xequ
               ywrt(ii) = yequ
            ENDDO
            npkt_wrt = npkt_equi
            DEALLOCATE(y2a, stat = all_status)
         ELSE                                              ! Matching form no spline needed
            ALLOCATE(xwrt(0:npkt     ),stat = all_status)  ! Allocate array for powder pattern ready to write
            ALLOCATE(ywrt(0:npkt     ),stat = all_status)  ! Allocate array for powder pattern ready to write
            xwrt = 0.0
            ywrt = 0.0
            DO ii = 1,npkt
               xwrt(ii) = xpl(ii)
               ywrt(ii) = ypl(ii)
            ENDDO
            npkt_wrt = npkt
         ENDIF                   ! pow_axis      == ??
      ELSEIF( cpow_form == 'q' ) THEN                       ! axis is Q
         IF ( pow_axis      == POW_AXIS_TTH  .or.  &        ! Non matching form, spline onto equidistant steps
              pow_four_type == POW_HIST              ) THEN ! DEBYE, always spline
            IF(out_user_limits) THEN                      ! User provided values
               pow_qmin   = out_user_values(1)
               pow_qmax   = out_user_values(2)
               pow_deltaq = out_user_values(3)
            ELSE                                          ! Convert q limits
               IF(pow_axis      == POW_AXIS_TTH) THEN
                  pow_qmin   = zpi*2/rlambda*sind(xmin)
                  pow_qmax   = zpi*2/rlambda*sind(xmax)
                  pow_deltaq = xpl(npkt)-xpl(npkt-1)
               ENDIF
            ENDIF
            IF(pow_qmin < xpl(1) ) THEN                     ! User lower limit too low!
               qmin =            (INT( (xpl(1)            )/pow_deltaq) + 1)*pow_deltaq
            ELSE
               qmin = pow_qmin
            ENDIF
            IF(pow_qmax > xpl(npkt) ) THEN                  ! User upper limit too high!
               qmax =            (INT( (         xpl(npkt))/pow_deltaq) - 1)*pow_deltaq
            ELSE
               qmax = pow_qmax
            ENDIF
            xmin =   qmin                                  ! Adjust limits needed later to cut 
            xmax =   qmax                                  ! off rounding errors
            npkt_equi =     NINT((qmax-qmin)/pow_deltaq) + 1             
            ALLOCATE(y2a (1:POW_MAXPKT),stat = all_status) ! Allocate array for calculated powder pattern
            ALLOCATE(xwrt(0:npkt_equi),stat = all_status)  ! Allocate array for powder pattern ready to write
            ALLOCATE(ywrt(0:npkt_equi),stat = all_status)  ! Allocate array for powder pattern ready to write
            xwrt = 0.0
            ywrt = 0.0
            y2a  = 0.0
            CALL spline (npkt, xpl, ypl, 1e31, 1e31, y2a)
            DO ii = 1, npkt_equi
               xequ = qmin + (ii-1)*pow_deltaq
               CALL splint (npkt, xpl, ypl, y2a, xequ, yequ)
               IF(ier_num/=0) THEN
                  DEALLOCATE( pow_tmp, stat = all_status)
                  DEALLOCATE( xpl, stat = all_status)
                  DEALLOCATE( ypl, stat = all_status)
                  DEALLOCATE( y2a, stat = all_status)
                  DEALLOCATE( xwrt, stat = all_status)
                  DEALLOCATE( ywrt, stat = all_status)
                  RETURN
               ENDIF
               xwrt(ii) = xequ
               ywrt(ii) = yequ
            ENDDO
            npkt_wrt = npkt_equi
            DEALLOCATE(y2a, stat = all_status)
         ELSE                                              ! Matching form no spline needed
            ALLOCATE(xwrt(0:npkt     ),stat = all_status)  ! Allocate array for powder pattern ready to write
            ALLOCATE(ywrt(0:npkt     ),stat = all_status)  ! Allocate array for powder pattern ready to write
            DO ii = 1,npkt
               xwrt(ii) = xpl(ii)
               ywrt(ii) = ypl(ii)
            ENDDO
            npkt_wrt = npkt
         ENDIF                   ! pow_axis      == ??
      ELSE                    ! cpow_form == 
         DO ii = 1,npkt
            xwrt(ii) = xpl(ii)
            ywrt(ii) = ypl(ii)
         ENDDO
         npkt_wrt = npkt
      ENDIF                   ! cpow_form == 
!
      cut: DO
         IF(xwrt(npkt_wrt) > xmax) THEN
            npkt_wrt = npkt_wrt-1  ! Truncate in case of rounding errors
         ELSEIF(xwrt(npkt_wrt) < xwrt(npkt_wrt-1)) THEN
            npkt_wrt = npkt_wrt-1  ! Truncate in case of rounding errors
         ELSE
           EXIT cut
         ENDIF
      ENDDO cut
!
!     Scale intensity and add a background
!
      IF(value==1) THEN
         DO ii=1,npkt_wrt
            ywrt(ii) = pow_scale*ywrt(ii)
            DO iii=0,pow_nback
               ywrt(ii) = ywrt(ii) + pow_back(iii)*xwrt(ii)**iii
            ENDDO
         ENDDO
      ENDIF
!
!     Finally write the pattern
!
      CALL powder_do_write (outfile, npkt_wrt, POW_MAXPKT, xwrt, ywrt)
!
      DEALLOCATE( pow_tmp, stat = all_status)
      DEALLOCATE( ypl, stat = all_status)
      DEALLOCATE( xpl, stat = all_status)
      DEALLOCATE( xwrt, stat = all_status)
      DEALLOCATE( ywrt, stat = all_status)
!                                                                       
      END SUBROUTINE powder_out                     
!*****7*****************************************************************
      REAL function lorentz (ttheta, flag_fq) 
!+                                                                      
!-                                                                      
      USE discus_config_mod 
      USE powder_mod 
      USE trig_degree_mod
      IMPLICIT none 
!                                                                       
!                                                                       
      REAL   , INTENT(IN) :: ttheta 
      INTEGER, INTENT(IN) :: flag_fq
!                                                                       
!
!     REAL sind
!                                                                       
      lorentz = 1.0
      
      IF (pow_four_type.eq.POW_DEBYE) THEN 
         lorentz = 1.0 
      ELSE 
         IF(flag_fq==0) THEN
         IF (pow_lp.eq.POW_LP_BRAGG) THEN 
            lorentz = 0.5 / sind (0.5 * ttheta) / sind (ttheta) 
         ELSEIF (pow_lp.eq.POW_LP_NEUT) THEN 
            lorentz = 0.5 / sind (0.5 * ttheta) / sind (ttheta) 
         ELSEIF (pow_lp.eq.POW_LP_NONE) THEN 
            lorentz = 1.0 
         ELSEIF (pow_lp.eq.POW_LP_SYNC) THEN 
            lorentz = 0.5 / sind (0.5 * ttheta) / sind (ttheta) 
         ENDIF 
         ELSEIF(flag_fq==1) THEN 
            lorentz = 0.5 / sind (0.5 * ttheta) / sind (ttheta) 
         ENDIF 
      ENDIF 
!                                                                       
      END FUNCTION lorentz                          
!*****7*****************************************************************
      REAL FUNCTION polarisation (ttheta) 
!+                                                                      
!-                                                                      
      USE discus_config_mod 
      USE powder_mod 
      USE trig_degree_mod
      IMPLICIT none 
!                                                                       
!                                                                       
      REAL ttheta 
!
!
!     REAL cosd 
!                                                                       
      polarisation = 1.0
      
      IF (pow_lp.eq.POW_LP_BRAGG) THEN 
         polarisation = (1. + (cosd (ttheta) ) **2 * pow_lp_fac)        &
         / (1. + pow_lp_fac)                                            
      ELSEIF (pow_lp.eq.POW_LP_NEUT) THEN 
         polarisation = 1.0 
      ELSEIF (pow_lp.eq.POW_LP_NONE) THEN 
         polarisation = 1.0 
      ELSEIF (pow_lp.eq.POW_LP_SYNC) THEN 
         polarisation = pow_lp_fac + (1. - pow_lp_fac) * (cosd (ttheta) &
         ) **2 * pow_lp_cos                                             
      ENDIF 
!                                                                       
      END FUNCTION polarisation                     
!*****7*****************************************************************
      REAL FUNCTION lorentz_pol (ttheta) 
!+                                                                      
!-                                                                      
      USE discus_config_mod 
      USE powder_mod 
      USE trig_degree_mod
      IMPLICIT none 
!                                                                       
!                                                                       
      REAL ttheta 
!                                                                       
!     REAL sind, cosd 
!                                                                       
      IF (pow_four_type.eq.POW_DEBYE) THEN 
         lorentz_pol = 1.0 
      ELSE
         lorentz_pol = (1-pow_lp_fac+pow_lp_fac*(cosd(pow_lp_ang))**2*(cosd(ttheta))**2)/ &
                       (2.*(sind(0.5*ttheta))**2*cosd(0.5*ttheta))
      ENDIF
      END FUNCTION lorentz_pol
!*****7*****************************************************************
      SUBROUTINE powder_conv_res (dat, tthmin, tthmax, dtth, delta, POW_MAXPKT)
!-                                                                      
!     Convolute powder pattern with resolution function (Gaussian)      
!+                                                                      
      USE discus_config_mod 
      USE wink_mod
      IMPLICIT none 
!                                                                       
!
      INTEGER, INTENT(IN) :: POW_MAXPKT
!                                                                       
      REAL dat (0:POW_MAXPKT) 
      REAL tthmin, tthmax, dtth, delta 
!                                                                       
      REAL dummy (0:POW_MAXPKT) 
      REAL gauss (0:2 * POW_MAXPKT) 
      REAL tth
      INTEGER imax, i, j, ii 
      INTEGER max_ps 
!                                                                       
!------ Setup Gaussian                                                  
!                                                                       
      max_ps = int( (10.0 * delta) / dtth )
      DO i = 0, max_ps 
      tth = i * dtth 
      gauss (i) = 1.0 / sqrt (pi) / delta * exp ( - (tth**2 / delta**2) &
      )                                                                 
      ENDDO 
!                                                                       
      DO i = max_ps + 1, 2 * POW_MAXPKT 
      gauss (i) = 0.0 
      ENDDO 
!                                                                       
!------ Now convolute                                                   
!                                                                       
      imax = int( (tthmax - tthmin) / dtth )
      DO i = 0, imax 
      dummy (i) = dat (i) * (gauss (0) - gauss (2 * i) ) 
      ii = max (i - 1 - max_ps + 1, 0) 
      DO j = ii, i - 1 
      dummy (i) = dummy (i) + dat (j) * (gauss (i - j) - gauss (i + j) ) 
      ENDDO 
      ii = min (i + 1 + max_ps - 1, imax) 
      DO j = i + 1, ii 
      dummy (i) = dummy (i) + dat (j) * (gauss (j - i) - gauss (j + i) ) 
      ENDDO 
      ENDDO 
!                                                                       
      DO i = 0, imax 
      dat (i) = dummy (i) !* dtth 
      ENDDO 
!                                                                       
      END SUBROUTINE powder_conv_res                
!*****7*****************************************************************
SUBROUTINE powder_conv_psvgt_fix (dat, tthmin, tthmax, dtth, eta, &
      w, pow_width, POW_MAXPKT)
!-                                                                      
!     Convolute powder pattern with resolution function (Pseudo-Voigt)  
!     Constant FWHM, Constant eta                                       
!+                                                                      
USE discus_config_mod 
USE wink_mod
IMPLICIT none 
!                                                                       
!
INTEGER, INTENT(IN) :: POW_MAXPKT
!                                                                       
REAL, DIMENSION(0:POW_MAXPKT), INTENT(INOUT) ::  dat !(0:POW_MAXPKT) 
REAL                         , INTENT(IN)    ::  tthmin, tthmax, dtth, eta
REAL                         , INTENT(IN)    ::  w 
REAL                         , INTENT(IN)    ::  pow_width 
!                                                                       
REAL                               :: fwhm
REAL, DIMENSION(0:POW_MAXPKT)      :: dummy
REAL, DIMENSION(0:2 * POW_MAXPKT)  :: psvgt
REAL                               :: tth
INTEGER                            :: imax, i, j, ii 
INTEGER                            :: max_ps 
!                                                                       
!REAL pseudovoigt 
!                                                                       
!------ Setup Pseudo-Voigt                                              
!                                                                       
fwhm = sqrt (abs (w) ) 
max_ps = int( (pow_width * fwhm) / dtth )
psvgt = 0.0
DO i = 0, max_ps 
   tth = i * dtth 
   psvgt (i) = pseudovoigt (tth, eta, fwhm) 
ENDDO 
!                                                                       
!     DO i = max_ps + 1, 2 * POW_MAXPKT 
!     psvgt (i) = 0.0 
!     ENDDO 
!                                                                       
!------ Now convolute                                                   
!                                                                       
      imax = int( (tthmax - tthmin) / dtth )
DO i = 0, imax 
   dummy (i) = dat (i) * (psvgt (0) - psvgt (2 * i) ) 
   ii = max (i - 1 - max_ps + 1, 0  ) 
   DO j = ii, i - 1 
      dummy (i) = dummy (i) + dat (j) * (psvgt (i - j) - psvgt (i + j) ) 
   ENDDO 
   ii = min (i + 1 + max_ps - 1, imax) 
   DO j = i + 1, ii 
      dummy (i) = dummy (i) + dat (j) * (psvgt (j - i) - psvgt (j + i) ) 
   ENDDO 
!      IF (i + ii.le.imax) THEN 
!         WRITE ( * , * ) ' i,j, psvgt(j-i), psvgt(j+i)', i, ii, psvgt ( &
!         ii - i) , psvgt (ii + i)                                       
!      ENDIF 
ENDDO 
!                                                                       
DO i = 0, imax 
   dat (i) = dummy (i) !* dtth 
ENDDO 
!                                                                       
END SUBROUTINE powder_conv_psvgt_fix          
!*****7*****************************************************************
      SUBROUTINE powder_conv_psvgt_uvw (dat, tthmin, tthmax, dtth, eta0,&
      etax, u, v, w, p1, p2, p3, p4, pow_width, POW_MAXPKT)
!-                                                                      
!     Convolute powder pattern with resolution function (Pseudo-Voigt)  
!     FWHM according to caglioti equation, Constant eta                 
!     FWHM = sqrt ( U*tan**2(Theta) + V*tan(Theta) + W)                 
!+                                                                      
      USE discus_config_mod 
      USE trig_degree_mod
      USE wink_mod
      IMPLICIT none 
!                                                                       
!
      INTEGER, INTENT(IN) :: POW_MAXPKT
!                                                                       
      REAL dat (0:POW_MAXPKT) 
      REAL tthmin, tthmax, dtth, fwhm, eta0, etax 
      REAL u, v, w 
      REAL p1, p2, p3, p4 
      REAL pow_width 
!                                                                       
      REAL dummy (0:POW_MAXPKT) 
      REAL tth
      REAL tantth 
      REAL tth1 
      REAL tth2 
      REAL atheta 
      REAL atwoth 
      REAL fwhm1 
      REAL eta 
      REAL pra1, pra2 
      INTEGER imax, i, j, ii 
      INTEGER max_ps 
!                                                                       
!      REAL pseudovoigt 
!      REAL profile_asymmetry 
!      REAL tand
!                                                                       
!------ Now convolute                                                   
!                                                                       
      imax = int( (tthmax - tthmin) / dtth )
      DO i = 0, imax 
      tth = tthmin + i * dtth 
      tantth = tand (tth * 0.5) 
      atheta = tth * 0.5 
      atwoth = tth 
      fwhm = sqrt (max (abs (u * tantth**2 + v * tantth + w), 0.00001) ) 
      fwhm1 = fwhm 
      max_ps = int( (pow_width * fwhm) / dtth )
      eta = min (1.0, max (0.0, eta0 + etax * tth) ) 
      tth1 = 0 * dtth 
      tth2 = 2 * i * dtth 
      pra1 = profile_asymmetry (tth, tth1, fwhm, p1, p2, p3, p4) 
      pra2 = profile_asymmetry (tth, tth2, fwhm, p1, p2, p3, p4) 
      dummy (i) = dat (i) * (pseudovoigt (tth1, eta, fwhm) * pra1 -     &
      pseudovoigt (tth2, eta, fwhm) * pra2)                             
!       do j=0,i-1                                                      
      ii = max (i - 1 - max_ps + 1, 0) 
      DO j = ii, i - 1 
      tth1 = (i - j) * dtth 
      tth2 = (i + j) * dtth 
      pra1 = profile_asymmetry (tth, tth1, fwhm, p1, p2, p3, p4) 
      pra2 = profile_asymmetry (tth, tth2, fwhm, p1, p2, p3, p4) 
      dummy (i) = dummy (i) + dat (j) * (pseudovoigt (tth1, eta, fwhm)  &
      * pra1 - pseudovoigt (tth2, eta, fwhm) * pra2)                    
      ENDDO 
!       do j=i+1,imax                                                   
      ii = min (i + 1 + max_ps - 1, imax) 
      DO j = i + 1, ii 
      tth1 = (j - i) * dtth 
      tth2 = (j + i) * dtth 
      pra1 = profile_asymmetry (tth, - tth1, fwhm, p1, p2, p3, p4) 
      pra2 = profile_asymmetry (tth, - tth2, fwhm, p1, p2, p3, p4) 
      dummy (i) = dummy (i) + dat (j) * (pseudovoigt (tth1, eta, fwhm)  &
      * pra1 - pseudovoigt (tth2, eta, fwhm) * pra2)                    
      ENDDO 
      ENDDO 
!                                                                       
      DO i = 0, imax 
      dat (i) = dummy (i) ! * dtth 
      ENDDO 
!                                                                       
      END SUBROUTINE powder_conv_psvgt_uvw          
!*****7*****************************************************************
      SUBROUTINE powder_conv_psvgt_uvw_Qscale (dat, tthmin, tthmax,     &
      dtth, eta0, etax, u, v, w, p1, p2, p3, p4, pow_width, rlambda,    &
      pow_axis, POW_AXIS_Q, POW_MAXPKT)                                             
!-                                                                      
!     Convolute powder pattern with resolution function (Pseudo-Voigt)  
!     FWHM according to caglioti equation, Constant eta                 
!     FWHM = sqrt ( U*tan**2(Theta) + V*tan(Theta) + W)                 
!+                                                                      
      USE discus_config_mod 
      USE trig_degree_mod
      USE wink_mod
      IMPLICIT none 
!                                                                       
!
      INTEGER, INTENT(IN) :: POW_MAXPKT
!                                                                       
      REAL dat (0:POW_MAXPKT) 
      REAL tthmin, tthmax, dtth, fwhm, eta0, etax 
      REAL u, v, w 
      REAL p1, p2, p3, p4 
      REAL pow_width 
      REAL rlambda 
      INTEGER pow_axis 
      INTEGER POW_AXIS_Q 
!                                                                       
      REAL dummy (0:POW_MAXPKT) 
      REAL tth
      REAL tantth 
      REAL tth1 
      REAL tth2 
      REAL atheta 
      REAL atwoth 
      REAL fwhm1 
      REAL eta 
      REAL pra1, pra2 
      INTEGER imax, i, j, ii 
      INTEGER max_ps 
!                                                                       
!      REAL pseudovoigt 
!      REAL profile_asymmetry 
!     REAL tand, sind, asind 
!                                                                       
!------ Now convolute                                                   
!                                                                       
      imax = int( (tthmax - tthmin) / dtth )
      DO i = 0, imax 
      tth = tthmin + i * dtth 
      tantth = tand (tth * 0.5) 
      atheta = tth * 0.5 
      atwoth = tth 
      fwhm = sqrt (max (abs (u * tantth**2 + v * tantth + w), 0.00001) ) 
      fwhm1 = fwhm 
      IF (pow_axis.eq.POW_AXIS_Q) THEN 
         atheta = asind (tth * rlambda / fpi) 
         tantth = tand (atheta) 
         fwhm1 = sqrt (max (abs (u * tantth**2 + v * tantth + w),       &
         0.00001) )                                                     
         fwhm = 0.500 * (fpi * sind (atheta + 0.5 * fwhm1) / rlambda -  &
         fpi * sind (atheta - 0.5 * fwhm1) / rlambda)                   
      ENDIF 
      max_ps = int( (pow_width * fwhm) / dtth )
      eta = min (1.0, max (0.0, eta0 + etax * tth) ) 
      tth1 = 0 * dtth 
      tth2 = 2 * i * dtth 
      pra1 = profile_asymmetry (tth, tth1, fwhm, p1, p2, p3, p4) 
      pra2 = profile_asymmetry (tth, tth2, fwhm, p1, p2, p3, p4) 
      dummy (i) = dat (i) * (pseudovoigt (tth1, eta, fwhm) * pra1 -     &
      pseudovoigt (tth2, eta, fwhm) * pra2)                             
!       do j=0,i-1                                                      
      ii = max (i - 1 - max_ps + 1, 0) 
      DO j = ii, i - 1 
      tth1 = (i - j) * dtth 
      tth2 = (i + j) * dtth 
      pra1 = profile_asymmetry (tth, tth1, fwhm, p1, p2, p3, p4) 
      pra2 = profile_asymmetry (tth, tth2, fwhm, p1, p2, p3, p4) 
      dummy (i) = dummy (i) + dat (j) * (pseudovoigt (tth1, eta, fwhm)  &
      * pra1 - pseudovoigt (tth2, eta, fwhm) * pra2)                    
      ENDDO 
!       do j=i+1,imax                                                   
      ii = min (i + 1 + max_ps - 1, imax) 
      DO j = i + 1, ii 
      tth1 = (j - i) * dtth 
      tth2 = (j + i) * dtth 
      pra1 = profile_asymmetry (tth, - tth1, fwhm, p1, p2, p3, p4) 
      pra2 = profile_asymmetry (tth, - tth2, fwhm, p1, p2, p3, p4) 
      dummy (i) = dummy (i) + dat (j) * (pseudovoigt (tth1, eta, fwhm)  &
      * pra1 - pseudovoigt (tth2, eta, fwhm) * pra2)                    
      ENDDO 
      ENDDO 
!                                                                       
      DO i = 0, imax 
      dat (i) = dummy (i) ! * dtth 
      ENDDO 
!                                                                       
      END SUBROUTINE powder_conv_psvgt_uvw_Qscale   
!*****7*****************************************************************
      REAL function pseudovoigt (dtth, eta, fwhm) 
!-                                                                      
!     calculates the value of a pseudo-voigt function at dtth off the   
!     central position                                                  
!                                                                       
      IMPLICIT none 
      REAL, INTENT(IN) :: dtth 
      REAL, INTENT(IN) :: eta 
      REAL, INTENT(IN) :: fwhm 
!                                                                       
      REAL, PARAMETER :: pi        = 3.141592654
      REAL, PARAMETER :: four_ln2  = 2.772588722
      REAL, PARAMETER :: sq4ln2_pi = 0.939437279
      REAL, PARAMETER :: two_pi    = 0.636619772
      REAL            :: pref_g 
      REAL            :: pref_l 
!                                                                       
!                                                                       
      pref_g = sq4ln2_pi / fwhm 
      pref_l = two_pi * fwhm 
!                                                                       
      pseudovoigt = eta * pref_l / (fwhm**2 + 4. * dtth**2) + (1. - eta)&
      * pref_g * exp ( - four_ln2 * (dtth / fwhm) **2)                  
!                                                                       
      END FUNCTION pseudovoigt                      
!*****7*****************************************************************
      REAL function profile_asymmetry (tth, dtth, fwhm, p1, p2, p3, p4) 
!-                                                                      
!     calculates the asymmetry parameter for the profile function       
!                                                                       
      USE trig_degree_mod
      IMPLICIT none 
!                                                                       
      REAL, INTENT(IN) :: tth 
      REAL, INTENT(IN) :: dtth 
      REAL, INTENT(IN) :: fwhm 
      REAL, INTENT(IN) :: p1, p2, p3, p4 
!                                                                       
      REAL :: zz 
      REAL :: fa, fb 
!                                                                       
!     REAL :: tand 
!                                                                       
      zz = dtth / fwhm 
!                                                                       
      fa = 2. * zz * exp ( - zz**2) 
      fb = 2. * (2. * zz**2 - 3.) * fa 
!                                                                       
      profile_asymmetry = 1.0 + (p1 * fa + p2 * fb) / tand (0.5 * tth)  &
      + (p3 * fa + p4 * fb) / tand (tth)                                
!                                                                       
      END FUNCTION profile_asymmetry                
!*****7*****************************************************************
!                                                                       
      SUBROUTINE spline (n, x, y, yp1, ypn, y2) 
!
!      PARAMETER (nmax = maxarray) 
!
      INTEGER,              INTENT(IN)  :: n
      REAL, DIMENSION(0:n), INTENT(IN)  :: x
      REAL, DIMENSION(0:n), INTENT(IN)  :: y
      REAL                , INTENT(IN)  :: yp1
      REAL                , INTENT(IN)  :: ypn
      REAL, DIMENSION(0:n), INTENT(OUT) :: y2
!
      INTEGER               :: i,k
      REAL, DIMENSION(1:n)  :: u
      REAL                  :: p, qn, sig, un
!
!     INTEGER  :: klo, khi, k
!     REAL     :: a,b
!     DIMENSION x (n), y (n), y2 (n), u (n) 
      IF (yp1.gt..99e30) THEN 
         y2 (1) = 0. 
         u (1) = 0. 
      ELSE 
         y2 (1) = - 0.5 
         u (1) = (3. / (x (2) - x (1) ) ) * ( (y (2) - y (1) ) /        &
         (x (2) - x (1) ) - yp1)                                        
      ENDIF 
      DO 11 i = 2, n - 1 
         sig = (x (i) - x (i - 1) ) / (x (i + 1) - x (i - 1) ) 
         p = sig * y2 (i - 1) + 2. 
         y2 (i) = (sig - 1.) / p 
         u (i) = (6. * ( (y (i + 1) - y (i) ) / (x (i + 1) - x (i) )    &
         - (y (i) - y (i - 1) ) / (x (i) - x (i - 1) ) ) / (x (i + 1)   &
         - x (i - 1) ) - sig * u (i - 1) ) / p                          
   11 END DO 
      IF (ypn.gt..99e30) THEN 
         qn = 0. 
         un = 0. 
      ELSE 
         qn = 0.5 
         un = (3. / (x (n) - x (n - 1) ) ) * (ypn - (y (n) - y (n - 1) )&
         / (x (n) - x (n - 1) ) )                                       
      ENDIF 
      y2 (n) = (un - qn * u (n - 1) ) / (qn * y2 (n - 1) + 1.) 
      DO 12 k = n - 1, 1, - 1 
         y2 (k) = y2 (k) * y2 (k + 1) + u (k) 
   12 END DO 
      RETURN 
      END SUBROUTINE spline                         
!*****7*****************************************************************
!                                                                       
      SUBROUTINE splint (n, xa, ya, y2a, x, y) 
!
      INTEGER,              INTENT(IN)  :: n
      REAL, DIMENSION(0:n), INTENT(IN)  :: xa
      REAL, DIMENSION(0:n), INTENT(IN)  :: ya
      REAL, DIMENSION(0:n), INTENT(IN)  :: y2a
      REAL                , INTENT(IN)  :: x
      REAL                , INTENT(OUT) :: y
      INTEGER  :: klo, khi, k
      REAL     :: a,b,h
!
      klo = 1 
      khi = n 
    1 IF (khi - klo.gt.1) THEN 
         k = (khi + klo) / 2 
         IF (xa (k) .gt.x) THEN 
            khi = k 
         ELSE 
            klo = k 
         ENDIF 
         GOTO 1 
      ENDIF 
      h = xa (khi) - xa (klo) 
      IF (h.eq.0.) THEN
         ier_num = -121
         ier_typ = ER_APPL
         WRITE(ier_msg(1),'(''x- pos: '',F10.4,2x, F10.4)') xa(khi), xa(klo)
         WRITE(ier_msg(2),'(''x- pos: '',I6   ,6x, I6  )' )    khi ,    klo 
         RETURN
      ENDIF
      a = (xa (khi) - x) / h 
      b = (x - xa (klo) ) / h 
      y = a * ya (klo) + b * ya (khi) + ( (a**3 - a) * y2a (klo)        &
      + (b**3 - b) * y2a (khi) ) * (h**2) / 6.                          
      RETURN 
      END SUBROUTINE splint                         
!*****7*****************************************************************
      SUBROUTINE powder_f2aver ( num1 )
!
!     This subroutine calculates the average atomic form factor
!     <f^2> and <f>^2
!
      USE crystal_mod 
      USE diffuse_mod 
      USE powder_mod 
      USE powder_tables_mod 
      USE wink_mod
!
      IMPLICIT NONE
!
      INTEGER,                INTENT(IN) :: num1
!
      INTEGER, DIMENSION(:), ALLOCATABLE :: natom
!
      INTEGER :: iscat
      INTEGER :: i
!!!
      pow_f2aver(:) = 0.0D0
      pow_faver2(:) = 0.0D0
      pow_u2aver    = 0.0
      pow_nreal     = 0
!
!     Prepare and calculate average atom numbers
!
      ALLOCATE(natom(0:cr_nscat))
      natom = 0
      DO i=1,cr_natoms
         natom(cr_iscat(i)) = natom(cr_iscat(i)) + 1
      ENDDO
      pow_nreal = SUM(natom)  ! Add real atom numbers 
!
      DO iscat = 1, cr_nscat
         DO i = 1, num1
            pow_f2aver (i) = pow_f2aver (i)  + &
                       DBLE (       cfact_pure(powder_istl(i), iscat)  * &
                             conjg (cfact_pure(powder_istl(i), iscat)))  &
                     * natom (iscat)/pow_nreal
            pow_faver2 (i) = pow_faver2 (i) +  &
                  SQRT(DBLE (       cfact_pure(powder_istl(i), iscat)  * &
                             conjg (cfact_pure(powder_istl(i), iscat)))) &
                     * natom (iscat)/pow_nreal
         ENDDO
         pow_u2aver = pow_u2aver + cr_dw(iscat) * natom (iscat)/pow_nreal
      ENDDO
      pow_faver2(:) = pow_faver2(:)**2
      pow_u2aver    = pow_u2aver /8./pi**2
      DEALLOCATE(natom)
!
!
      END SUBROUTINE powder_f2aver
END MODULE powder_write_mod
