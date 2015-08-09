module focas_energy
  use focas_data

  implicit none

  contains

  subroutine compute_energy(int1,int2,den1,den2)
    implicit none
    real(wp), intent(in) :: int1(:),int2(:),den1(:),den2(:)

    ! initialize values
    e1_c_          = 0.0_wp
    e1_a_          = 0.0_wp
    e2_cc_         = 0.0_wp
    e2_ca_         = 0.0_wp
    e2_aa_         = 0.0_wp   
    e_frozen_core_ = 0.0_wp

    ! compute core contribution to 1-e energy ; 2 indeces \in D
    call compute_core_1e(int1,e1_c_)

    ! compute active contribution to 1-e energy ; 2 indeces \in A
    call compute_active_1e(int1,den1,e1_a_)

    ! compute core-core contribution to 2-e energy ; 4 indeces \in D
    call compute_core_core_2e(int2,e2_cc_)

    ! compute core-active contribution to 2-e energy ; 2 indeces \in D && 2 indeces \in A
    call compute_core_active_2e(int2,den1,e2_ca_) 

    ! compute active-active contribution to 2-e energy ; 4 indeces \in A
    call compute_active_active_2e(int2,den2,e2_aa_)

    ! frozen core energy
    e_frozen_core_ = e1_c_ + e2_cc_

    ! total energy
    e_total_       = e1_c_ + e1_a_ + e2_cc_ + e2_ca_ + e2_aa_

    ! active energy
    e_active_      = e_total_ - e_frozen_core_

    ! total 1-e energy
    e1_total_      = e1_c_ + e1_a_

    ! total 2-e energy
    e2_total_      = e2_cc_ + e2_ca_ + e2_aa_

    return
  end subroutine compute_energy

  subroutine compute_core_1e(int1,e_out)
    implicit none
    ! subroutine to accumulate 1-e contribution to the core energy given by
    ! e1_core = 2.0 * SUM(i \in D) h(i|i)
    real(wp), intent(in) :: int1(:)
    real(wp) :: e_out
    integer :: i,i_sym
    integer(ip) :: ii

    ! initialize energy

    e_out = 0.0_wp

    ! loop over irreps for i

    do i_sym = 1 , nirrep_

      ! loop over i indeces ( i \in D )

      do i = first_index_(i_sym,1) , last_index_(i_sym,1)

        ! geminal index

        ii = ints_%gemind(i,i)

        ! update core energy

        e_out = e_out + int1(ii)

      end do ! end i loop

    end do ! end i_sym loop

    ! take into account double occupancy of orbital

    e_out = 2.0_wp * e_out

    return
  end subroutine compute_core_1e

  subroutine compute_active_1e(int1,den1,e_out)
    implicit none
    ! subroutine to accumulate the 1-e contribution to the active energy given by
    ! e1_active = sum(i,j \in A) { h(i|j) * d1(i|j) }
    ! because d1 and h are symmetric, we can perform a restricted (i<=j) summation 
    ! and multiply the off-diagonal elements by 2
    real(wp), intent(in) :: int1(:),den1(:)
    real(wp) :: e_out
    integer :: i,j,i_sym
    integer(ip) :: ij_den,ij_int
    real(wp) :: e_scr

    ! initialize 1-e active energy

    e_out = 0.0_wp

    ! loop over irreps for i (not that j_sym == i_sym) 

    do i_sym = 1, nirrep_

      ! loop over i indeces ( i \in A )

      do i = first_index_(i_sym,2) , last_index_(i_sym,2)

        ! diagonal element
        ij_int = ints_%gemind(i,i)
        ij_den = dens_%gemind(i,i)
        e_out  = e_out + den1(ij_den) * int1(ij_int)

        ! initialize temporary e value
        e_scr = 0.0_wp

        do j = i + 1 , last_index_(i_sym,2)

          ! off-diagonal element
          ij_int = ints_%gemind(i,j)
          ij_den = dens_%gemind(i,j)
          e_scr = e_scr + den1(ij_den) * int1(ij_int)

        end do ! end j loop

        ! update active 1-e energy (factor of 2 comes from permutational symmetry)

        e_out = e_out + 2.0_wp * e_scr

      end do ! end i loop

    end do ! end i_sym loop
    return
  end subroutine compute_active_1e

  subroutine compute_core_core_2e(int2,e_out)
    implicit none
    ! subroutine to accumulate 2-e contribution to the core energy given by
    ! e2_core = sum(i,j \in D) { 2g(ii|jj) - g(ij|ij) }
    ! NOTE: the coulomb terms g(ii|jj) belong to the totally symmetric irrep
    real(wp), intent(in) :: int2(:)
    real(wp) :: e_out,coulomb,exchange
    integer :: j_sym,i_sym,ij_sym,i,j
    integer(ip) :: ii,jj,int_ind,ij,ij_offset
    
    ! initialize coulomb and exchange energies

    coulomb  = 0.0_wp
    exchange = 0.0_wp

    ! loop over irreps for i

    do i_sym = 1 , nirrep_

      ! loop over irreps for j

      do j_sym = 1 , nirrep_

        ! loop over i indeces

        do i = first_index_(i_sym,1) , last_index_(i_sym,1)
 
          ! ii-geminal index
          ii = ints_%gemind(i,i)
  
          ! loop over j indeces

          do j = first_index_(j_sym,1) , last_index_(j_sym,1)             
 
            ! jj geminal index
            jj        = ints_%gemind(j,j)
            ! ij geminal index
            ij        = ints_%gemind(i,j)
            ! ij symmetry
            ij_sym    = group_mult_tab_(i_sym,j_sym)
            ! ij geminal offset
            ij_offset = ints_%offset(ij_sym) 
            ! Coulomb contribution // g(ii,jj) ... i,j \in C)
            int_ind   = pq_index(ii,jj)
            coulomb   = coulomb + int2(int_ind)
            ! exchange contribution // g(ij|ij) ... i,j \in C 
            int_ind   = pq_index(ij,ij) + ij_offset
            exchange  = exchange + int2(int_ind)

          end do ! end j loop

        end do ! end i loop

      end do ! end j_sym loop

    end do ! end i_sym loop

    ! subtract the exchange terms from twice the coulomb terms
    e_out = 2.0_wp * coulomb - exchange

    return
  end subroutine compute_core_core_2e

  subroutine compute_core_active_2e(int2,den1,e_out)
    implicit none
    ! subroutine to compute the core-active contribution to the 2-e energy
    ! e = 0.5 * sum(ij \in A & k \in D) { 2 * d(i|j) * [ 2g(ij|kk) - g(ik|jk) ] }
    real(wp), intent(in) :: int2(:),den1(:)
    real(wp) :: e_out
    integer :: i,j,k,i_sym,k_sym,ik_sym
    integer(ip) :: ik_offset,int_ind,ij_int,ij_den,kk,ik,jk,ijkk,ikjk
    real(wp) :: coulomb,exchange

    ! initialize energy value
    e_out = 0.0_wp

    ! loop over irreps for i
 
    do i_sym = 1 , nirrep_

      ! loop over irreps for k

      do k_sym = 1 , nirrep_

        ! ik geminal symmetry
        ik_sym    = group_mult_tab_(i_sym,k_sym)
        ! ik geminal offset
        ik_offset = ints_%offset(ik_sym) 

        ! loop over i indeces

        do i = first_index_(i_sym,2) , last_index_(i_sym,2)

          ! loop over j indeces 

          do j = first_index_(i_sym,2) , last_index_(i_sym,2)

            ! ij geminal integral index
            ij_int = ints_%gemind(i,j)

            ! initialize coulomb and exhange contributions
            coulomb  = 0.0_wp
            exchange = 0.0_wp

            ! loop over k indeces

            do k = first_index_(k_sym,1) , last_index_(k_sym,1)

              ! kk geminal index
              kk       = ints_%gemind(k,k)
              ! Coulomb contribution
              ijkk     = pq_index(ij_int,kk)
              coulomb  = coulomb + int2(ijkk)
 
              ! ik/jk geminal indeces
              ik       = ints_%gemind(i,k)
              jk       = ints_%gemind(j,k)
              ! exchange contribution
              ikjk     = pq_index(ik,jk) + ik_offset
              exchange = exchange + int2(ikjk)

            end do ! end k loop

            ! ij geminal density index
            ij_den = dens_%gemind(i,j)
            ! add up terms
            e_out = e_out + den1(ij_den) * ( 2.0_wp * coulomb - exchange )

          end do ! end j loop

        end do ! end i loop
        
      end do ! end k_sym loop 
 
    end do ! end i_sym loop

    return
  end subroutine compute_core_active_2e

  subroutine compute_active_active_2e(int2,den2,e_out)
    implicit none
    ! subroutine to compute active-active contribution to 2-electron energy
    ! e = 0.5 * sum(ijkl \in A) { d2(ij|kl) * g(ij|kl) }
    real(wp), intent(in) :: int2(:),den2(:) 
    real(wp) :: e_out
    integer :: i,j,k,l,i_sym,j_sym,k_sym,l_sym,ij_sym
    integer(ip) :: ij_int,kl_int,ij_den,kl_den,ij_den_offset,ij_int_offset,den_ind,int_ind
     
    ! initialize energy
    e_out = 0.0_wp

    ! loop over irreps for i
    
    do i_sym = 1 , nirrep_

      ! loop over irreps for j
     
      do j_sym = 1 , nirrep_

        ! ij geminal symmetry    
        ij_sym        = group_mult_tab_(i_sym,j_sym)
        ! ij geminal integral offset
        ij_int_offset = ints_%offset(ij_sym)
        ! ij geminal density offset
        ij_den_offset = dens_%offset(ij_sym)

        ! loop over irreps for k

        do k_sym = 1 , nirrep_

          ! figure out symmetry of l such that ij_sym == kl_sym
          l_sym = group_mult_tab_(ij_sym,k_sym)

          ! loop over i indeces
 
          do i = first_index_(i_sym,2) , last_index_(i_sym,2)

            ! loop over j indeces

            do j = first_index_(j_sym,2) , last_index_(j_sym,2)

! debug
!              if ( i < j ) cycle

              ! ij geminal integral index
              ij_int = ints_%gemind(i,j)
              ! ij geminal density index
              ij_den = dens_%gemind(i,j)

              do k = first_index_(k_sym,2) , last_index_(k_sym,2)

                do l = first_index_(l_sym,2) , last_index_(l_sym,2)

! debug
!                  if ( k < l ) cycle

                  ! kl geminal integral index
                  kl_int  = ints_%gemind(k,l)

! debug
!                  if (ij_int < kl_int ) cycle

                  ! ij geminal density index
                  kl_den  = dens_%gemind(k,l)
                  ! integral g(ij|kl) index 
                  int_ind = pq_index(ij_int,kl_int) + ij_int_offset
                  ! density d2(ij|kl) index 
                  den_ind = pq_index(ij_den,kl_den) + ij_den_offset
                  ! update 2-e active contribution
                  e_out   = e_out + int2(int_ind) * den2(den_ind) 

                end do ! end l loop

              end do ! end k loop

            end do ! end j_loop

          end  do ! end i loop

        end do ! end k_sym loop

      end  do ! end j_sym loop

    end do ! end i_sym loop

    e_out = 0.5_wp * e_out 

    return
  end subroutine compute_active_active_2e

end module focas_energy