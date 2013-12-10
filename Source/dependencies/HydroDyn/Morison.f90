!**********************************************************************************************************************************
! The Morison and Morison_Types modules make up a template for creating user-defined calculations in the FAST Modularization 
! Framework. Morisons_Types will be auto-generated based on a description of the variables for the module.
!
! "Morison" should be replaced with the name of your module. Example: HydroDyn
! "Morison" (in Morison_*) should be replaced with the module name or an abbreviation of it. Example: HD
!..................................................................................................................................
! LICENSING
! Copyright (C) 2012  National Renewable Energy Laboratory
!
!    This file is part of Morison.
!
! Licensed under the Apache License, Version 2.0 (the "License");
! you may not use this file except in compliance with the License.
! You may obtain a copy of the License at
!
!     http://www.apache.org/licenses/LICENSE-2.0
!
! Unless required by applicable law or agreed to in writing, software
! distributed under the License is distributed on an "AS IS" BASIS,
! WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
! See the License for the specific language governing permissions and
!    
!**********************************************************************************************************************************
! File last committed: $Date: 2013-11-15 13:21:41 -0700 (Fri, 15 Nov 2013) $
! (File) Revision #: $Rev: 292 $
! URL: $HeadURL: https://windsvn.nrel.gov/HydroDyn/branches/HydroDyn_Modularization/Source/Morison.f90 $
!**********************************************************************************************************************************
MODULE Morison
   USE Waves
   USE Morison_Types  
   USE Morison_Output
  ! USE HydroDyn_Output_Types
   USE NWTC_Library

   
   IMPLICIT NONE
   
   PRIVATE

!   INTEGER(IntKi), PARAMETER            :: DataFormatID = 1   ! Update this value if the data types change (used in Morison_Pack)
   TYPE(ProgDesc), PARAMETER            :: Morison_ProgDesc = ProgDesc( 'Morison', '(v1.00.01, 1-Apr-2013)', '1-Apr-2013' )

   
      ! ..... Public Subroutines ...................................................................................................
   PUBLIC:: Morison_ProcessMorisonGeometry
   
   PUBLIC :: Morison_Init                           ! Initialization routine
   PUBLIC :: Morison_End                            ! Ending routine (includes clean up)
   
   PUBLIC :: Morison_UpdateStates                   ! Loose coupling routine for solving for constraint states, integrating 
                                                    !   continuous states, and updating discrete states
   PUBLIC :: Morison_CalcOutput                     ! Routine for computing outputs
   
   PUBLIC :: Morison_CalcConstrStateResidual        ! Tight coupling routine for returning the constraint state residual
   PUBLIC :: Morison_CalcContStateDeriv             ! Tight coupling routine for computing derivatives of continuous states
   PUBLIC :: Morison_UpdateDiscState                ! Tight coupling routine for updating discrete states
      
   !PUBLIC :: Morison_JacobianPInput                 ! Routine to compute the Jacobians of the output (Y), continuous- (X), discrete-
   !                                                 !   (Xd), and constraint-state (Z) equations all with respect to the inputs (u)
   !PUBLIC :: Morison_JacobianPContState             ! Routine to compute the Jacobians of the output (Y), continuous- (X), discrete-
   !                                                 !   (Xd), and constraint-state (Z) equations all with respect to the continuous 
   !                                                 !   states (x)
   !PUBLIC :: Morison_JacobianPDiscState             ! Routine to compute the Jacobians of the output (Y), continuous- (X), discrete-
   !                                                 !   (Xd), and constraint-state (Z) equations all with respect to the discrete 
   !                                                 !   states (xd)
   !PUBLIC :: Morison_JacobianPConstrState           ! Routine to compute the Jacobians of the output (Y), continuous- (X), discrete-
   !                                                 !   (Xd), and constraint-state (Z) equations all with respect to the constraint 
                                                    !   states (z)
   
   
CONTAINS

SUBROUTINE Morison_DirCosMtrx( pos0, pos1, DirCos )

! Compute the direction cosine matrix given two points along the axis of a cylinder

   REAL(ReKi), INTENT( IN    )  ::   pos0(3), pos1(3)
   Real(ReKi), INTENT(   OUT )  ::   DirCos(3,3)
   Real(DbKi)                   ::   xz, xyz
   Real(DbKi)                   ::   x0, y0, z0
   Real(DbKi)                   ::   x1, y1, z1
   Real(DbKi)                   ::   temp

   x0 = pos0(1)
   y0 = pos0(2)
   z0 = pos0(3)
   x1 = pos1(1)
   y1 = pos1(2)
   z1 = pos1(3)
   
      ! Need to verify that z0 <= z1, but this was already handled in the element construction process!!! GJH 9/24/13 
   !IF ( z0 > z1 ) THEN
   !   temp = x0
   !   x0   = x1
   !   x1   = temp
   !   temp = y0
   !   y0   = y1
   !   y1   = temp
   !   temp = z0
   !   z0   = z1
   !   z1   = temp
   !END IF
   
   xz  = sqrt((x0-x1)*(x0-x1)+(z0-z1)*(z0-z1))
   xyz = sqrt((x0-x1)*(x0-x1)+(y0-y1)*(y0-y1)+(z0-z1)*(z0-z1))
   
   IF ( xz==0 ) THEN
      
      IF (y1<y0) THEN
         
         DirCos = transpose(reshape((/ 1, 0, 0, 0, 0, -1, 0, 1, 0 /), shape(DirCos)))
          
      ELSE
         
         DirCos = transpose(reshape((/ 1, 0, 0, 0, 0, 1, 0, -1, 0 /), shape(DirCos)))
         
      END IF
      
   ELSE
      
      DirCos(1, 1) = -(z0-z1)/xz
      DirCos(1, 2) = -(x0-x1)*(y0-y1)/(xz*xyz)
      DirCos(1, 3) = (x1-x0)/xyz
      
      DirCos(2, 1) = 0.0
      DirCos(2, 2) = xz/xyz
      DirCos(2, 3) = (y1-y0)/xyz
      
      DirCos(3, 1) = -(x1-x0)/xz
      DirCos(3, 2) = -(y0-y1)*(z0-z1)/(xz*xyz)
      DirCos(3, 3) = (z1-z0)/xyz
      
      ! DEBUG:  TODO : Remove
      !PRINT*, sqrt(DirCos(1,1)*DirCos(1,1) + DirCos(1,2)*DirCos(1,2)+DirCos(1,3)*DirCos(1,3))
      !PRINT*, sqrt(DirCos(2,1)*DirCos(2,1) + DirCos(2,2)*DirCos(2,2)+DirCos(2,3)*DirCos(2,3))
      !PRINT*, sqrt(DirCos(3,1)*DirCos(3,1) + DirCos(3,2)*DirCos(3,2)+DirCos(3,3)*DirCos(3,3))
   END IF    
   
END SUBROUTINE Morison_DirCosMtrx

!====================================================================================================
SUBROUTINE GetDistance ( a, b, l )
!    This private subroutine computes the distance between points a and b.
!---------------------------------------------------------------------------------------------------- 

   REAL(ReKi), INTENT ( IN    )  :: a(3)     ! the position of point a
   REAL(ReKi), INTENT ( IN    )  :: b(3)     ! the position of point b
   REAL(ReKi), INTENT (   OUT )  :: l        ! the distance between point a and b
   
   l = sqrt( ( a(1) - b(1) ) * ( a(1) - b(1) ) + ( a(2) - b(2) ) * ( a(2) - b(2) ) + ( a(3) - b(3) ) * ( a(3) - b(3) ) )
   
END SUBROUTINE GetDistance

!====================================================================================================
SUBROUTINE ElementCentroid ( Rs, Re, p1, h, DCM, centroid )
!    This private subroutine computes the centroid of a tapered right cylinder element.
!---------------------------------------------------------------------------------------------------- 

   REAL(ReKi), INTENT ( IN    )  :: Rs          ! starting radius
   REAL(ReKi), INTENT ( IN    )  :: Re          ! ending radius
   REAL(ReKi), INTENT ( IN    )  :: p1(3)       ! starting point of the element in global coordinates
   REAL(ReKi), INTENT ( IN    )  :: h           ! height of the element
   REAL(ReKi), INTENT ( IN    )  :: DCM(3,3)    ! direction cosine matrix to transform local element coordinates to global coordinates
   REAL(ReKi), INTENT (   OUT )  :: centroid(3) ! centroid of the element in local coordinates
   
   centroid(1) = 0.0
   centroid(2) = 0.0
   centroid(3) = h * (Rs*Rs + 2.0*Rs*Re +  3.0*Re*Re) / (4.0*( Rs*Rs + Rs*Re +  Re*Re  ) )                    !( 2.0*Re + Rs ) / ( 3.0 * ( Rs + Re ) )
   centroid    = matmul( DCM, centroid ) + p1
   
END SUBROUTINE ElementCentroid

!====================================================================================================
REAL(ReKi) FUNCTION ElementVolume ( Rs, Re, h )
!    This private function computes the volume of a tapered right cylinder element.
!---------------------------------------------------------------------------------------------------- 

   REAL(ReKi), INTENT ( IN    )  :: Rs          ! starting radius
   REAL(ReKi), INTENT ( IN    )  :: Re          ! ending radius
   REAL(ReKi), INTENT ( IN    )  :: h           ! height of the element
   
   ElementVolume = Pi*h*( Rs*Rs + Re*Re + Rs*Re  ) / 3.0
   
END FUNCTION ElementVolume

!====================================================================================================
SUBROUTINE    FindInterpFactor( p, p1, p2, s )

   REAL(ReKi),  INTENT ( IN    )  :: p, p1, p2
   REAL(ReKi),  INTENT (   OUT )  :: s
   
   REAL(ReKi)                     :: dp
! find normalized interpolation factor, s, such:
! p = p1*(1-s) + p2*s
!  *--------------*--------------------------------*
!  p1             p                                p2
!
!  0-----------------------------------------------1
!  <------- s ---->
   
   dp = p2 - p1
   IF ( EqualRealNos(dp, 0.0_ReKi) ) THEN
      s = 0
   ELSE
      s = ( p - p1  ) / dp 
   END IF
         
END SUBROUTINE FindInterpFactor




SUBROUTINE DistrBuoyancy( L, densWater, R1, tMG1, Z1, R2, tMG2, Z2, C, g, F_B  ) 

   REAL(ReKi),         INTENT ( IN    )  :: L
   REAL(ReKi),         INTENT ( IN    )  :: densWater
   REAL(ReKi),         INTENT ( IN    )  :: R1
   REAL(ReKi),         INTENT ( IN    )  :: tMG1
   REAL(ReKi),         INTENT ( IN    )  :: Z1
   REAL(ReKi),         INTENT ( IN    )  :: R2
   REAL(ReKi),         INTENT ( IN    )  :: tMG2
   REAL(ReKi),         INTENT ( IN    )  :: Z2
   REAL(ReKi),         INTENT ( IN    )  :: C(3,3)
   REAL(ReKi),         INTENT ( IN    )  :: g
   REAL(ReKi),         INTENT (   OUT )  :: F_B(6)
   
   REAL(DbKi)                           :: R1eff,R2eff,V,f1,f2,f3,f4,f5,f6,f7,f8
    
   R1eff  = (R1+tMG1)
   R2eff  = (R2+tMG2)
   
   ! Switching buoyancy calculations per conversations with Jason 9/20/13
   
   V      = L*( R1eff*R1eff + R2eff*R2eff + R1eff*R2eff  ) / 3
   f1     = densWater*g/L
   f2     = Z1*R1eff*R1eff
   f3     = Z2*R2eff*R2eff
   f4     = (f2-f3)
   f5     = -Pi*C(3,2)*R1eff*R1eff*R1eff*R1eff/4
   f6     = Pi*C(3,1)*R1eff*R1eff*R1eff*R1eff/4
   f7     = Pi*C(3,2)*R2eff*R2eff*R2eff*R2eff/4
   f8     = -Pi*C(3,1)*R2eff*R2eff*R2eff*R2eff/4
   
   F_B(1) = Pi*f1*C(1,3)*f4
   F_B(2) = Pi*f1*C(2,3)*f4
   F_B(3) = Pi*f1*(V + C(3,3)*f4)
   F_B(4) = f1*((C(1,1)*f5 + C(1,2)*f6)+(C(1,1)*f7+C(1,2)*f8))
   F_B(5) = f1*((C(2,1)*f5 + C(2,2)*f6)+(C(2,1)*f7+C(2,2)*f8))
   F_B(6) = f1*((C(3,1)*f5 + C(3,2)*f6)+(C(3,1)*f7+C(3,2)*f8))
   
   
END SUBROUTINE DistrBuoyancy


SUBROUTINE DistrBuoyancy2( densWater, R, tMG, dRdz, Z, C, g, F_B  ) 

   REAL(ReKi),         INTENT ( IN    )  :: densWater
   REAL(ReKi),         INTENT ( IN    )  :: R
   REAL(ReKi),         INTENT ( IN    )  :: tMG
   REAL(ReKi),         INTENT ( IN    )  :: dRdz
   REAL(ReKi),         INTENT ( IN    )  :: Z
   REAL(ReKi),         INTENT ( IN    )  :: C(3,3)
   REAL(ReKi),         INTENT ( IN    )  :: g
   REAL(ReKi),         INTENT (   OUT )  :: F_B(6)
   
   REAL(DbKi)                           :: Reff,ReffSq,ReffCub,f1,f2,f3
   
   REAL(DbKi) :: CC(3,3)
   CC = DBLE(C)
   Reff  = DBLE(R + tMG)
  
   
   
   ReffSq  = Reff*Reff 
   ReffCub = ReffSq*Reff
   f1      = DBLE(densWater)*DBLE(g)*pi
   f2      = f1*ReffCub*DBLE(dRdz)
   f3      = Reff*DBLE(dRdz)*DBLE(Z)
   
   !F_B(1) = f1*( C(3,1)*ReffSq )
   !F_B(2) = f1*( C(3,2)*ReffSq  )
   !F_B(3) = f1*(  - 2*C(3,3)*f3 )
   !F_B(4) = f2*( C(3,2) )
   !F_B(5) = f2*( - C(3,1) )
   !F_B(6) = f2*( 0.0 )
   
   F_B(1) = f1*( (CC(1,1)*CC(3,1) + CC(1,2)*CC(3,2))*ReffSq - 2.0*CC(1,3)*f3 )
   F_B(2) = f1*( (CC(2,1)*CC(3,1) + CC(2,2)*CC(3,2))*ReffSq - 2.0*CC(2,3)*f3 )
   F_B(3) = f1*( (CC(3,1)*CC(3,1) + CC(3,2)*CC(3,2))*ReffSq - 2.0*CC(3,3)*f3 )
   F_B(4) = -f2*( CC(1,1)*CC(3,2) - CC(1,2)*CC(3,1) )
   F_B(5) = -f2*( CC(2,1)*CC(3,2) - CC(2,2)*CC(3,1) )
   F_B(6) = -f2*( CC(3,1)*CC(3,2) - CC(3,2)*CC(3,1) )
   
   
END SUBROUTINE DistrBuoyancy2


SUBROUTINE DistrInertialLoads( nodeIndx, densWater, Ca, R, tMG, k, NStepWave, WaveAcc0, F_I, ErrStat, ErrMsg  )

   INTEGER,            INTENT ( IN    )  :: nodeIndx
   REAL(ReKi),         INTENT ( IN    )  :: densWater
   REAL(ReKi),         INTENT ( IN    )  :: Ca
   REAL(ReKi),         INTENT ( IN    )  :: R
   REAL(ReKi),         INTENT ( IN    )  :: tMG
   REAL(ReKi),         INTENT ( IN    )  :: k(3)
   INTEGER,            INTENT ( IN    )  :: NStepWave
   REAL(ReKi),         INTENT ( IN    )  :: WaveAcc0(0:,:,:)
   REAL(ReKi),ALLOCATABLE,  INTENT (   OUT )  :: F_I(:,:)
   INTEGER,            INTENT (   OUT )  :: ErrStat              ! returns a non-zero value when an error occurs  
   CHARACTER(*),       INTENT (   OUT )  :: ErrMsg               ! Error message if ErrStat /= ErrID_None

   INTEGER                               :: I
   REAL(ReKi)                            :: f, v_len
   REAL(ReKi)                            :: p0(3), m(3), v(3), l(3)
   
      ! Initialize ErrStat
         
   ErrStat = ErrID_None         
   ErrMsg  = "" 
      
      ! Allocate F_DP
   ALLOCATE ( F_I(0:NStepWave, 6), STAT = ErrStat )
   IF ( ErrStat /= ErrID_None ) THEN
      ErrMsg  = ' Error allocating distributed inertial loads array.'
      ErrStat = ErrID_Fatal
      RETURN
   END IF  
   
   DO I=0,NStepWave
      l =  WaveAcc0(I,nodeIndx,:)
      m =  Cross_Product( k, l )
      v =  Cross_Product( m, k )
      !CALL GetDistance( p0, v, v_len )  
      !TODO What about multiplying by the magnitude?
      f = (Ca + 1)*densWater*Pi*(R+tMG)*(R+tMG)  ! *v_len    TODO:  I commented out this last factor because it is not in our equations document. GJH 5/21/13
      F_I(I,1) = f*v(1)
      F_I(I,2) = f*v(2)
      F_I(I,3) = f*v(3)
      F_I(I,4) = 0.0
      F_I(I,5) = 0.0
      F_I(I,6) = 0.0
   END DO
   
END SUBROUTINE DistrInertialLoads


SUBROUTINE DistrMGLoads(MGdens, g, R, tMG, F_MG )  
   REAL(ReKi),         INTENT ( IN    )  :: MGdens
   REAL(ReKi),         INTENT ( IN    )  :: g
   REAL(ReKi),         INTENT ( IN    )  :: R
   REAL(ReKi),         INTENT ( IN    )  :: tMG
   REAL(ReKi),         INTENT (   OUT )  :: F_MG(6)
   
   F_MG(:) = 0.0
   F_MG(3) = -MGdens*g*Pi* ( (R + tMG ) * ( R + tMG ) - R*R )
   
END SUBROUTINE DistrMGLoads


SUBROUTINE DistrDynPressure( nodeIndx, C, R, tMG, dRdz, NStepWave, WaveDynP0, F_DP, ErrStat, ErrMsg )

   INTEGER,            INTENT ( IN    )  :: nodeIndx
   REAL(ReKi),         INTENT ( IN    )  :: C(3,3)
   REAL(ReKi),         INTENT ( IN    )  :: R
   REAL(ReKi),         INTENT ( IN    )  :: tMG
   REAL(ReKi),         INTENT ( IN    )  :: dRdz
   INTEGER,            INTENT ( IN    )  :: NStepWave
   REAL(ReKi),         INTENT ( IN    )  :: WaveDynP0(0:,:)
   REAL(ReKi),ALLOCATABLE,         INTENT (   OUT )  :: F_DP(:,:)
   INTEGER,            INTENT (   OUT )  :: ErrStat              ! returns a non-zero value when an error occurs  
   CHARACTER(*),       INTENT (   OUT )  :: ErrMsg               ! Error message if ErrStat /= ErrID_None

   INTEGER                               :: I
   
      ! Initialize ErrStat
         
   ErrStat = ErrID_None         
   ErrMsg  = "" 
   
   
      ! Allocate F_DP
   ALLOCATE ( F_DP(0:NStepWave,6), STAT = ErrStat )
   IF ( ErrStat /= ErrID_None ) THEN
      ErrMsg  = ' Error allocating distributed dynamic pressure loads array.'
      ErrStat = ErrID_Fatal
      RETURN
   END IF  
   
   DO I=0,NStepWave
      F_DP(I,1) = C(1,3)*2.0*Pi*(R+tMG)*dRdz*WaveDynP0(I,nodeIndx) 
      F_DP(I,2) = C(2,3)*2.0*Pi*(R+tMG)*dRdz*WaveDynP0(I,nodeIndx) 
      F_DP(I,3) = C(3,3)*2.0*Pi*(R+tMG)*dRdz*WaveDynP0(I,nodeIndx) 
      F_DP(I,4) = 0.0
      F_DP(I,5) = 0.0
      F_DP(I,6) = 0.0
   END DO
   
   
END SUBROUTINE DistrDynPressure



            
         
            
           
SUBROUTINE DistrDragConst( densWater, Cd, R, tMG, DragConst  ) 

   ! This is used to minimize the computations which occur at each timestep
   
   REAL(ReKi),         INTENT ( IN    )  :: Cd
   REAL(ReKi),         INTENT ( IN    )  :: densWater
   REAL(ReKi),         INTENT ( IN    )  :: R
   REAL(ReKi),         INTENT ( IN    )  :: tMG
   REAL(ReKi),         INTENT (   OUT )  :: DragConst
   
   DragConst = Cd*densWater*(R+tMG)
   
END SUBROUTINE DistrDragConst


SUBROUTINE DistrFloodedBuoyancy( L, densFluid, Z_f, R1, tM1, Z1, R2, tM2, Z2, C, g, F_B )  

   REAL(ReKi),         INTENT ( IN    )  :: L
   REAL(ReKi),         INTENT ( IN    )  :: densFluid
   REAL(ReKi),         INTENT ( IN    )  :: Z_f
   REAL(ReKi),         INTENT ( IN    )  :: R1
   REAL(ReKi),         INTENT ( IN    )  :: tM1
   REAL(ReKi),         INTENT ( IN    )  :: Z1
   REAL(ReKi),         INTENT ( IN    )  :: R2
   REAL(ReKi),         INTENT ( IN    )  :: tM2
   REAL(ReKi),         INTENT ( IN    )  :: Z2
   REAL(ReKi),         INTENT ( IN    )  :: C(3,3)
   REAL(ReKi),         INTENT ( IN    )  :: g
   REAL(ReKi),         INTENT (   OUT )  :: F_B(6)

   REAL(DbKi)                           :: V,f1,f2,f3,f4,f5,f6,f7,f8
   
   V      = Pi*L*((R1-tM1)*(R1-tM1) + (R2-tM2)*(R2-tM2) + (R1-tM1)*(R2-tM2)  ) / 3
   f1     = densFluid*g/L
   f2     = -(Z1-Z_f)*Pi*(R1-tM1)*(R1-tM1)
   f3     =  (Z2-Z_f)*Pi*(R2-tM2)*(R2-tM2)
   f4     = (f1*f2+f1*f3)
   
   f5     = -Pi*C(3,2)*(R1-tM1)*(R1-tM1)*(R1-tM1)*(R1-tM1)/4
   f6     = Pi*C(3,1)*(R1-tM1)*(R1-tM1)*(R1-tM1)*(R1-tM1)/4
   f7     = Pi*C(3,2)*(R2-tM2)*(R2-tM2)*(R2-tM2)*(R2-tM2)/4
   f8     = -Pi*C(3,1)*(R2-tM2)*(R2-tM2)*(R2-tM2)*(R2-tM2)/4
   
   F_B(1) = C(1,3)*f4
   F_B(2) = C(2,3)*f4
   F_B(3) = -densFluid*g*V/L + C(3,3)*f4
   F_B(4) = f1*(C(1,1)*f5 + C(1,2)*f6)+f1*(C(1,1)*f7+C(1,2)*f8)
   F_B(5) = f1*(C(2,1)*f5 + C(2,2)*f6)+f1*(C(2,1)*f7+C(2,2)*f8)
   F_B(6) = f1*(C(3,1)*f5 + C(3,2)*f6)+f1*(C(3,1)*f7+C(3,2)*f8)
   
   
   
END SUBROUTINE DistrFloodedBuoyancy


SUBROUTINE DistrFloodedBuoyancy2( densFluid, Z_f, R, t, dRdz, Z, C, g, F_B  ) 

   REAL(ReKi),         INTENT ( IN    )  :: densFluid
   REAL(ReKi),         INTENT ( IN    )  :: Z_f
   REAL(ReKi),         INTENT ( IN    )  :: R
   REAL(ReKi),         INTENT ( IN    )  :: t
   REAL(ReKi),         INTENT ( IN    )  :: dRdz
   REAL(ReKi),         INTENT ( IN    )  :: Z
   REAL(ReKi),         INTENT ( IN    )  :: C(3,3)
   REAL(ReKi),         INTENT ( IN    )  :: g
   REAL(ReKi),         INTENT (   OUT )  :: F_B(6)
   
   REAL(DbKi)                           :: Zeff,Reff,ReffSq,ReffCub,f1,f2,f3
    
   !Reff  = (R - t)
   !Zeff  = (Z - Z_f)
   !
   !
   !ReffSq  = Reff*Reff 
   !ReffCub = ReffSq*Reff
   !f1      = densFluid*g*pi
   !f2      = f1*ReffCub*dRdz
   !f3      = Reff*dRdz*Zeff
   !
   !F_B(1) = f1*( C(1,1)*C(3,1)*ReffSq + C(1,2)*C(3,2)*ReffSq - 2*C(1,3)*f3 )
   !F_B(2) = f1*( C(2,1)*C(3,1)*ReffSq + C(2,2)*C(3,2)*ReffSq - 2*C(2,3)*f3 )
   !F_B(3) = f1*( C(3,1)*C(3,1)*ReffSq + C(3,2)*C(3,2)*ReffSq - 2*C(3,3)*f3 )
   !F_B(4) = f2*( C(1,1)*C(3,2) - C(1,2)*C(3,1) )
   !F_B(5) = f2*( C(2,1)*C(3,2) - C(2,2)*C(3,1) )
   !F_B(6) = f2*( C(3,1)*C(3,2) - C(3,2)*C(3,1) )
   
   !REAL(DbKi)                           :: Reff,ReffSq,ReffCub,f1,f2,f3
   
   REAL(DbKi) :: CC(3,3)
   CC = DBLE(C)
   
  
   Reff  =  DBLE(R - t)
   Zeff  = DBLE(Z - Z_f)
   
   ReffSq  = Reff*Reff 
   ReffCub = ReffSq*Reff
   f1      = -DBLE(densFluid)*DBLE(g)*pi
   f2      = f1*ReffCub*DBLE(dRdz)
   f3      = Reff*DBLE(dRdz)*Zeff
   
   !F_B(1) = f1*( C(3,1)*ReffSq )
   !F_B(2) = f1*( C(3,2)*ReffSq  )
   !F_B(3) = f1*(  - 2*C(3,3)*f3 )
   !F_B(4) = f2*( C(3,2) )
   !F_B(5) = f2*( - C(3,1) )
   !F_B(6) = f2*( 0.0 )
   
   F_B(1) = f1*( (CC(1,1)*CC(3,1) + CC(1,2)*CC(3,2))*ReffSq - 2.0*CC(1,3)*f3 )
   F_B(2) = f1*( (CC(2,1)*CC(3,1) + CC(2,2)*CC(3,2))*ReffSq - 2.0*CC(2,3)*f3 )
   F_B(3) = f1*( (CC(3,1)*CC(3,1) + CC(3,2)*CC(3,2))*ReffSq - 2.0*CC(3,3)*f3 )
   F_B(4) = -f2*( CC(1,1)*CC(3,2) - CC(1,2)*CC(3,1) )
   F_B(5) = -f2*( CC(2,1)*CC(3,2) - CC(2,2)*CC(3,1) )
   F_B(6) = -f2*( CC(3,1)*CC(3,2) - CC(3,2)*CC(3,1) )
   
END SUBROUTINE DistrFloodedBuoyancy2

SUBROUTINE DistrAddedMass( densWater, Ca, C, R, tMG, AM_M)

   REAL(ReKi),         INTENT ( IN    )  :: densWater
   REAL(ReKi),         INTENT ( IN    )  :: Ca
   REAL(ReKi),         INTENT ( IN    )  :: C(3,3)
   REAL(ReKi),         INTENT ( IN    )  :: R
   REAL(ReKi),         INTENT ( IN    )  :: tMG
   REAL(ReKi),         INTENT (   OUT )  :: AM_M(6,6)
   
   REAL(ReKi)                            :: f
   
   f         = Ca*densWater*Pi*(R+tMG)*(R+tMG)
   AM_M      = 0.0
   AM_M(1,1) = f*(  C(2,3)*C(2,3) + C(3,3)*C(3,3) )
   AM_M(1,2) = f*( -C(1,3)*C(2,3)                 )
   AM_M(1,3) = f*( -C(1,3)*C(3,3)                 )
   
   AM_M(2,1) = f*( -C(1,3)*C(2,3)                 )
   AM_M(2,2) = f*(  C(1,3)*C(1,3) + C(3,3)*C(3,3) )
   AM_M(2,3) = f*( -C(2,3)*C(3,3)                 )
   
   AM_M(3,1) = f*( -C(1,3)*C(3,3)                 )
   AM_M(3,2) = f*( -C(2,3)*C(3,3)                 )
   AM_M(3,3) = f*(  C(1,3)*C(1,3) + C(2,3)*C(2,3) )


END SUBROUTINE DistrAddedMass


SUBROUTINE DistrAddedMassMG( densMG, R, tMG, AM_MG)

   REAL(ReKi),         INTENT ( IN    )  :: densMG
   REAL(ReKi),         INTENT ( IN    )  :: R
   REAL(ReKi),         INTENT ( IN    )  :: tMG
   REAL(ReKi),         INTENT (   OUT )  :: AM_MG(6,6)
   
   AM_MG(:,:) = 0.0
   AM_MG(1,1) = densMG*Pi*((R+tMG)*(R+tMG) - R*R)
   AM_MG(2,2) = AM_MG(1,1)
   AM_MG(3,3) = AM_MG(1,1)
   
END SUBROUTINE DistrAddedMassMG


SUBROUTINE DistrAddedMassFlood( densFluid, R, t, AM_F)

   REAL(ReKi),         INTENT ( IN    )  :: densFluid
   REAL(ReKi),         INTENT ( IN    )  :: R
   REAL(ReKi),         INTENT ( IN    )  :: t
   REAL(ReKi),         INTENT (   OUT )  :: AM_F(6,6)
   
   AM_F(:,:) = 0.0
   AM_F(1,1) = densFluid*Pi*(R-t)*(R-t)
   AM_F(2,2) = AM_F(1,1)
   AM_F(3,3) = AM_F(1,1)
   
END SUBROUTINE DistrAddedMassFlood
         
         

SUBROUTINE LumpDragConst( densWater, Cd, R, tMG, DragConst  ) 

   ! This is used to minimize the computations which occur at each timestep
   
   REAL(ReKi),         INTENT ( IN    )  :: Cd
   REAL(ReKi),         INTENT ( IN    )  :: densWater
   REAL(ReKi),         INTENT ( IN    )  :: R
   REAL(ReKi),         INTENT ( IN    )  :: tMG
   REAL(ReKi),         INTENT (   OUT )  :: DragConst
   
   DragConst = 0.5*Cd*densWater*(R+tMG)*(R+tMG)
   
END SUBROUTINE LumpDragConst

         
SUBROUTINE LumpDynPressure( nodeIndx, k, R, tMG, NStepWave, WaveDynP0, F_DP, ErrStat, ErrMsg )


   INTEGER,            INTENT ( IN    )  :: nodeIndx
   REAL(ReKi),         INTENT ( IN    )  :: k(3)
   REAL(ReKi),         INTENT ( IN    )  :: R
   REAL(ReKi),         INTENT ( IN    )  :: tMG
   INTEGER,            INTENT ( IN    )  :: NStepWave
   REAL(ReKi),         INTENT ( IN    )  :: WaveDynP0(0:,:)
   REAL(ReKi),ALLOCATABLE,         INTENT (   OUT )  :: F_DP(:,:)
   INTEGER,            INTENT (   OUT )  :: ErrStat              ! returns a non-zero value when an error occurs  
   CHARACTER(*),       INTENT (   OUT )  :: ErrMsg               ! Error message if ErrStat /= ErrID_None

   INTEGER                               :: I
   
      ! Initialize ErrStat
         
   ErrStat = ErrID_None         
   ErrMsg  = "" 
   
   
      ! Allocate F_DP
      
   ALLOCATE ( F_DP(0:NStepWave,6), STAT = ErrStat )
   IF ( ErrStat /= ErrID_None ) THEN
      ErrMsg  = ' Error allocating distributed dynamic pressure loads array.'
      ErrStat = ErrID_Fatal
      RETURN
   END IF  
   
   DO I=0,NStepWave
      F_DP(I,1) = k(1)*Pi*(R+tMG)*(R+tMG)*WaveDynP0(I,nodeIndx) 
      F_DP(I,2) = k(2)*Pi*(R+tMG)*(R+tMG)*WaveDynP0(I,nodeIndx) 
      F_DP(I,3) = k(3)*Pi*(R+tMG)*(R+tMG)*WaveDynP0(I,nodeIndx) 
      F_DP(I,4) = 0.0
      F_DP(I,5) = 0.0
      F_DP(I,6) = 0.0
   END DO
   
   
END SUBROUTINE LumpDynPressure



SUBROUTINE LumpBuoyancy( sgn, densWater, R, tMG, Z, C, g, F_B  ) 

   REAL(ReKi),         INTENT ( IN    )  :: sgn
   REAL(ReKi),         INTENT ( IN    )  :: densWater
   REAL(ReKi),         INTENT ( IN    )  :: R
   REAL(ReKi),         INTENT ( IN    )  :: tMG
   REAL(ReKi),         INTENT ( IN    )  :: Z
   REAL(ReKi),         INTENT ( IN    )  :: C(3,3)
   REAL(ReKi),         INTENT ( IN    )  :: g
   REAL(ReKi),         INTENT (   OUT )  :: F_B(6)


   REAL(DbKi)                            :: f, f1, f2, f3, Reff, Rsq,R_4
   Reff = DBLE(R+tMG)
   Rsq  = Reff**2
   R_4  = Rsq**2
   f  = DBLE(g)*DBLE(densWater)*DBLE(sgn)
   f1 = -Z*Pi*Rsq
   f2 = f*Pi*R_4
   f3 =  C(3,1)*R_4

   F_B(1) = C(1,3)*f1*f
   F_B(2) = C(2,3)*f1*f
   F_B(3) = C(3,3)*f1*f
   F_B(4) =  0.25*( -C(3,2)*C(1,1) + C(1,2)*C(3,1) )*f2   ! TODO: We flipped the signs of the moments because 1 member tapered integrated moments were not zero.  GJH 10/1/13  Jason is verifying.
   F_B(5) =  0.25*( -C(3,2)*C(2,1) + C(2,2)*C(3,1) )*f2
   F_B(6) =  0.25*( -C(3,2)*C(3,1) + C(3,2)*C(3,1) )*f2
   
   
END SUBROUTINE LumpBuoyancy



SUBROUTINE LumpFloodedBuoyancy( sgn, densFill, R, tM, FillFS, Z, C, g, F_BF  ) 

   REAL(ReKi),         INTENT ( IN    )  :: sgn
   REAL(ReKi),         INTENT ( IN    )  :: densFill
   REAL(ReKi),         INTENT ( IN    )  :: R
   REAL(ReKi),         INTENT ( IN    )  :: tM
   REAL(ReKi),         INTENT ( IN    )  :: FillFS
   REAL(ReKi),         INTENT ( IN    )  :: Z
   REAL(ReKi),         INTENT ( IN    )  :: C(3,3)
   REAL(ReKi),         INTENT ( IN    )  :: g
   REAL(ReKi),         INTENT (   OUT )  :: F_BF(6)

   
   REAL(ReKi)                            :: f, f1, f2, f3
   
   f  = -densFill*g*sgn
   
   f1 = -(Z - FillFS)*Pi*       (R-tM)*(R-tM)
   f2 = 0.25*Pi*(R-tM)*(R-tM)*(R-tM)*(R-tM)
   

   F_BF(1) = C(1,3)*f1*f
   F_BF(2) = C(2,3)*f1*f
   F_BF(3) = C(3,3)*f1*f
   F_BF(4) =  (-C(1,1)*C(3,2) + C(1,2)*C(3,1))*f*f2   ! TODO: We flipped the signs of the moments because 1 member tapered integrated moments were not zero.  GJH 10/1/13  Jason is verifying.
   F_BF(5) =  (-C(2,1)*C(3,2) + C(2,2)*C(3,1))*f*f2
   F_BF(6) =  (-C(3,1)*C(3,2) + C(3,2)*C(3,1))*f*f2
   
   
END SUBROUTINE LumpFloodedBuoyancy

LOGICAL FUNCTION IsThisSplitValueUsed(nSplits, splits, checkVal)

   INTEGER,                        INTENT    ( IN    )  :: nSplits
   REAL(ReKi),                     INTENT    ( IN    )  :: splits(:)
   REAL(ReKi),                     INTENT    ( IN    )  :: checkVal
   
   INTEGER             :: I
   
   DO I=1,nSplits
      IF ( EqualRealNos(splits(I), checkVal ) ) THEN
         IsThisSplitValueUsed = .TRUE.
         RETURN
      END IF
END DO

   IsThisSplitValueUsed = .FALSE.
   
END FUNCTION IsThisSplitValueUsed
!====================================================================================================
SUBROUTINE GetMaxSimQuantities( numMGDepths, MGTop, MGBottom, MSL2SWL, Zseabed, filledGroups, numJoints, joints, numMembers, members, maxNodes, maxElements, maxSuperMembers )
!     This private subroutine determines the maximum nodes, elements, and super members which may appear
!     in the final simulation mesh.  This is based on the following:
!     1) Member splitting at the marine growth boundaries ( new nodes and members )
!     2) Member splitting due to internal subdivision ( new nodes and members )
!     3) New nodes and super members if a joint marked with JointOvrlp = 1 (and additional conditions are satisfied)
!     
!---------------------------------------------------------------------------------------------------- 
   INTEGER,                        INTENT    ( IN    )  :: numMGDepths              ! number of MGDepths specified in the input table
   REAL(ReKi),                     INTENT    ( IN    )  :: MGTop                    ! Global Z-value of the upper marine growth boundary
   REAL(ReKi),                     INTENT    ( IN    )  :: MGBottom                 ! Global Z-value of the lower marine growth boundary
   REAL(ReKi),                     INTENT    ( IN    )  :: MSL2SWL                  ! Global Z-value of mean sea level
   REAL(ReKi),                     INTENT    ( IN    )  :: Zseabed                  ! Global Z-value of the top of the seabed
   TYPE(Morison_FilledGroupType),  INTENT    ( IN    )  :: filledGroups(:)
   INTEGER,                        INTENT    ( IN    )  :: numJoints                ! number of joints specified in the inputs
   TYPE(Morison_JointType),        INTENT    ( IN    )  :: joints(:)                ! array of input joint data structures
   INTEGER,                        INTENT    ( IN    )  :: numMembers               ! number of members specified in the inputs
   TYPE(Morison_MemberInputType),  INTENT    ( INOUT )  :: members(:)               ! array of input member data structures
   INTEGER,                        INTENT    (   OUT )  :: maxNodes                 ! maximum number of nodes which may appear in the final simulation mesh
   INTEGER,                        INTENT    (   OUT )  :: maxElements              ! maximum number of elements which may appear in the final simulation mesh
   INTEGER,                        INTENT    (   OUT )  :: maxSuperMembers          ! maximum number of super members which may appear in the final simulation mesh
   
      ! Local variables
   INTEGER                                              :: WtrSplitCount = 0         ! number of possible new members due to splitting at water boundaries   
   INTEGER                                              :: MGsplitCount = 0         ! number of possible new members due to splitting at marine growth boundaries
   INTEGER                                              :: maxSubMembers = 0        ! maximum added nodes and members due to member subdivision
   INTEGER                                              :: maxSuperMemNodes = 0     ! maximum number of new nodes due to super member generation
   INTEGER                                              :: I, J, j1, j2             ! generic integer for counting
   TYPE(Morison_JointType)                           :: joint1, joint2           ! joint data structures                               
   Real(ReKi)                                           :: z1, z2                   ! z values of the first and second joints
   INTEGER                                              :: temp                     ! temporary variable
   REAL(ReKi)                                           :: memLen                   ! member length
   INTEGER                                              :: nSplits, totalSplits, nodeSplits
   REAL(ReKi)                                           :: possibleSplits(5)
      ! Initialize quantities
   maxNodes         = numJoints
   maxElements      = numMembers
   maxSuperMembers  = 0
   maxSuperMemNodes = 0
   maxSubMembers    = 0
   MGsplitCount     = 0
   WtrSplitCount    = 0
   nodeSplits       = 0
   totalSplits      = 0 
       
      ! Determine new members and nodes due to internal member subdivision
   DO I = 1,numMembers
       
              
      z1 = joints( members(I)%MJointID1Indx )%JointPos(3)
      z2 = joints( members(I)%MJointID2Indx )%JointPos(3)
      IF ( z1 > z2) THEN
         temp = z1
         z1   = z2
         z2   = temp
      END IF
      
      
      
         ! For this member, determine possible split conditions due to crossing through:
         ! MSL, seabed, marine growth boundaries, filled free surface location.
         !
         
      nSplits = 0  
      possibleSplits = -9999999.0  ! Initialize possibleSplit values to a number that never appears in the geometry.
      
         ! Is the member filled?
      IF ( members(I)%MmbrFilledIDIndx /= -1 ) THEN
         nSplits =  1
         possibleSplits(1) = filledGroups(members(I)%MmbrFilledIDIndx)%FillFSLoc
      END IF
      
      
         ! Check if MSL is equal to Zfs, if it is, then don't add MSL2SWL as an additional possible split, otherwise do add it.
     
         IF ( .NOT. IsThisSplitValueUsed(nSplits, possibleSplits, MSL2SWL) ) THEN
            nSplits = nSplits + 1
            possibleSplits(nSplits) = MSL2SWL
         END IF  
      
      
        ! Is there a marine growth region?
        
      IF ( numMGDepths > 0 ) THEN   
         
            ! Recursively check to see if this
            IF ( .NOT. IsThisSplitValueUsed(nSplits, possibleSplits, MGTop) ) THEN
               nSplits = nSplits + 1
               possibleSplits(nSplits) = MGTop
            END IF
            IF ( .NOT. IsThisSplitValueUsed(nSplits, possibleSplits, MGBottom) ) THEN
               nSplits = nSplits + 1
               possibleSplits(nSplits) = MGBottom
            END IF
         
      END IF
      
        ! Check if seabed is equal to other possibleSplits
      
         IF ( .NOT. IsThisSplitValueUsed(nSplits, possibleSplits, Zseabed) ) THEN
            nSplits = nSplits + 1
            possibleSplits(nSplits) = Zseabed
         END IF  
     
         
       ! Now determine which possible splits this member actually crosses
       
      DO J=1,nSplits
         
         IF ( z1 < possibleSplits(J) .AND. z2 > possibleSplits(J) ) THEN
            members(I)%NumSplits = members(I)%NumSplits + 1
            members(I)%Splits(members(I)%NumSplits) = possibleSplits(J)
         END IF
      
      END DO
         ! Sort the splits from smallest Z value to largest Z value
      CALL BSortReal ( members(I)%Splits, members(I)%NumSplits )
      totalSplits = totalSplits + members(I)%NumSplits
      
      !   ! Determine new members due to elements crossing the MSL or the seabed
      !IF ( z2 > MSL2SWL ) THEN
      !   IF ( z1 < MSL2SWL .AND. z1 >= Zseabed ) THEN
      !      ! Split this member
      !      WtrSplitCount = WtrSplitCount + 1
      !      members(I).WtrSplitState = 1
      !   END IF
      !   IF ( z1 < Zseabed ) THEN
      !      ! Split this member twice because it crosses both boundaries
      !      WtrSplitCount = WtrSplitCount + 2
      !      members(I).WtrSplitState = 3
      !   END IF  
      !END IF
      !IF ( z2 < MSL2SWL .AND. z2 >= Zseabed ) THEN
      !   IF ( z1 < MGBottom ) THEN
      !      ! Split this member
      !      WtrSplitCount = WtrSplitCount + 1
      !      members(I).WtrSplitState = 2
      !   END IF
      !         
      !END IF
      !      
      !   ! Determine new members and nodes due to marine growth boundary splitting
      !   members(I).MGSplitState = 0
      !IF ( numMGDepths > 0 ) THEN
      !   
      !   IF ( z2 > MGTop ) THEN
      !      IF ( z1 < MGTop .AND. z1 >= MGBottom ) THEN
      !         ! Split this member
      !         MGsplitCount = MGsplitCount + 1
      !         members(I).MGSplitState = 1
      !      END IF
      !      IF ( z1 < MGBottom ) THEN
      !         ! Split this member twice because it crosses both boundaries
      !         MGsplitCount = MGsplitCount + 2
      !         members(I).MGSplitState = 3
      !      END IF  
      !   END IF
      !   IF ( z2 < MGTop .AND. z2 >= MGBottom ) THEN
      !      IF ( z1 < MGBottom ) THEN
      !         ! Split this member
      !         MGsplitCount = MGsplitCount + 1
      !         members(I).MGSplitState = 2
      !      END IF
      !         
      !   END IF
      !           
      !END IF
      
      j1 = members(I)%MJointID1Indx
      j2 = members(I)%MJointID2Indx
      joint1 = joints(j1)
      joint2 = joints(j2)
      CALL GetDistance(joint1%JointPos, joint2%JointPos, memLen)
      maxSubMembers = maxSubMembers + CEILING( memLen / members(I)%MDivSize  ) - 1
      
   END DO
   
      ! Look for all possible super member creation
   DO I = 1,numJoints
            
         ! Check #1 are there more than 2 members connected to the joint?
      IF ( joints(I)%JointOvrlp == 1 .AND. joints(I)%NConnections > 2) THEN
            maxSuperMemNodes = maxSuperMemNodes + ( joints(I)%NConnections - 1 )
            maxSuperMembers  = maxSuperMembers  + 1  
      ELSE
         nodeSplits = nodeSplits + joints(I)%NConnections - 1
      END IF
            
            
   END DO
   
   maxNodes        = maxNodes    + totalSplits*2 +  nodeSplits + maxSubMembers + maxSuperMemNodes
   maxElements     = maxElements + totalSplits + maxSubMembers
   
   
END SUBROUTINE GetMaxSimQuantities

SUBROUTINE WriteSummaryFile( UnSum, MSL2SWL, numNodes, nodes, numElements, elements, NOutputs, OutParam, NMOutputs, MOutLst, NJOutputs, JOutLst, inLumpedMesh, outLumpedMesh, inDistribMesh, outDistribMesh, L_F_B, L_F_BF, D_F_B, D_F_BF, D_F_MG, g, ErrStat, ErrMsg )  !, numDistribMarkers, distribMarkers, numLumpedMarkers, lumpedMarkers

   REAL(ReKi),               INTENT ( IN    )  :: MSL2SWL
   INTEGER,                  INTENT ( IN    )  :: UnSum
   INTEGER,                  INTENT ( IN    )  :: numNodes
   TYPE(Morison_NodeType),   INTENT ( IN    )  :: nodes(:)  
   INTEGER,                  INTENT ( IN    )  :: numElements
   TYPE(Morison_MemberType), INTENT ( IN    )  :: elements(:)
   INTEGER,                  INTENT ( IN    )  :: NOutputs
   TYPE(OutParmType),        INTENT ( IN    )  :: OutParam(:)
   INTEGER,                  INTENT ( IN    )  :: NMOutputs
   TYPE(Morison_MOutput),    INTENT ( IN    )  :: MOutLst(:)
   INTEGER,                  INTENT ( IN    )  :: NJOutputs
   TYPE(Morison_JOutput),    INTENT ( IN    )  :: JOutLst(:)
   TYPE(MeshType),           INTENT ( INOUT )  :: inLumpedMesh
   TYPE(MeshType),           INTENT ( INOUT )  :: outLumpedMesh
   TYPE(MeshType),           INTENT ( INOUT )  :: inDistribMesh
   TYPE(MeshType),           INTENT ( INOUT )  :: outDistribMesh
   REAL(ReKi),               INTENT ( IN    )  :: L_F_B(:,:)           ! Lumped buoyancy force associated with the member
   REAL(ReKi),               INTENT ( IN    )  :: L_F_BF(:,:)          ! Lumped buoyancy force associated flooded/filled fluid within the member
   REAL(ReKi),               INTENT ( IN    )  :: D_F_B(:,:)           ! Lumped buoyancy force associated with the member
   REAL(ReKi),               INTENT ( IN    )  :: D_F_BF(:,:)          ! Lumped buoyancy force associated flooded/filled fluid within the member
   REAL(ReKi),               INTENT ( IN    )  :: D_F_MG(:,:)
   REAL(ReKi),               INTENT ( IN    )  :: g                    ! gravity
   !INTEGER,                  INTENT ( IN    )  :: numDistribMarkers
   !TYPE(Morison_NodeType),   INTENT ( IN    )  :: distribMarkers(:)
   !INTEGER,                  INTENT ( IN    )  :: numLumpedMarkers
   !TYPE(Morison_NodeType),   INTENT ( IN    )  :: lumpedMarkers(:)
   INTEGER,                  INTENT (   OUT )  :: ErrStat             ! returns a non-zero value when an error occurs  
   CHARACTER(*),             INTENT (   OUT )  :: ErrMsg              ! Error message if ErrStat /= ErrID_None

   INTEGER                                     :: I, J
   REAL(ReKi)                                  :: l                   ! length of an element
   LOGICAL                                     :: filledFlag          ! flag indicating if element is filled/flooded
   CHARACTER(2)                                :: strFmt
   CHARACTER(10)                               :: strNodeType         ! string indicating type of node: End, Interior, Super
   REAL(ReKi)                                  :: ident(3,3)          ! identity matrix
   REAL(ReKi)                                  :: ExtBuoyancy(6)      ! sum of all external buoyancy forces lumped at (0,0,0)
   REAL(ReKi)                                  :: IntBuoyancy(6)      ! sum of all internal buoyancy forces lumped at (0,0,0)
   REAL(ReKi)                                  :: MG_Wt(6)            ! weight of the marine growth as applied to (0,0,0)
   TYPE(MeshType)                              :: WRP_Mesh            ! mesh representing the WAMIT reference point (0,0,0)
   TYPE(MeshMapType)                           :: M_L_2_P             ! Map  Morison Line2 to  WRP_Mesh point
   TYPE(MeshMapType)                           :: M_P_2_P             ! Map  Morison Line2 to  WRP_Mesh point
   REAL(ReKi)                                  :: elementVol            ! displaced volume of an element
   REAL(ReKi)                                  :: totalDisplVol       ! total displaced volume of the structure
   REAL(ReKi)                                  :: totalVol            ! total volume of structure
   REAL(ReKi)                                  :: MGvolume            ! volume of the marine growth material
   REAL(ReKi)                                  :: totalMGVol          !
   REAL(ReKi)                                  :: totalFillVol        !
   REAL(ReKi)                                  :: elemCentroid(3)     ! location of the element centroid
   REAL(ReKi)                                  :: COB(3)              ! center of buoyancy location in global coordinates
   INTEGER                                     :: m1, m2              ! Indices of the markers which surround the requested output location
   REAL(ReKi)                                  :: s                   ! The linear interpolation factor for the requested location
   REAL(ReKi)                                  :: outloc(3)           ! Position of the requested member output
   INTEGER                                     :: mbrIndx, nodeIndx
   CHARACTER(10)                               :: tmpName
   REAL(ReKi)                                  :: totalFillMass, mass_fill, fillVol
   REAL(ReKi)                                  :: totalMGMass, mass_MG
   TYPE(Morison_NodeType)                      ::  node1, node2
   
   
      ! Initialize data
   ErrStat       = ErrID_None
   ErrMsg        = ""
   ExtBuoyancy   = 0.0
   totalFillMass = 0.0
   totalDisplVol = 0.0
   totalVol      = 0.0
   totalMGVol    = 0.0
   totalFillVol  = 0.0
   totalMGMass   = 0.0
   COB           = 0.0
   
      ! Create identity matrix
   CALL EYE(ident,ErrStat,ErrMsg)
   
   IF ( UnSum > 0 ) THEN
      
         ! Write the header for this section
      WRITE( UnSum,  '(//)' ) 
      WRITE( UnSum,  '(A5)' ) 'Nodes'
      WRITE( UnSum,  '(/)' ) 
      WRITE( UnSum, '(1X,A5,19(2X,A10),2X,A5,2X,A15)' ) '  i  ', 'JointIndx ', 'JointOvrlp', 'InpMbrIndx', '   Nxi    ', '   Nyi    ', '   Nzi    ', 'InpMbrDist', '   tMG    ', '  MGDens  ', 'PropWAMIT ', 'FilledFlag', ' FillDens ', 'FillFSLoc ', '    Cd    ', '    Ca    ', '     R    ', '   dRdZ   ', '    t     ', ' NodeType ','NConn ', 'Connection List'
      WRITE( UnSum, '(1X,A5,19(2X,A10),2X,A5,2X,A15)' ) ' (-) ', '   (-)    ', '   (-)    ', '   (-)    ', '   (m)    ', '   (m)    ', '   (m)    ', '    (-)   ', '    (m)   ', ' (kg/m^3) ', '   (-)    ', '   (-)    ', ' (kg/m^3) ', '    (-)   ', '    (-)   ', '    (-)   ', '    (m)   ', '    (-)   ', '    (m)   ', '    (-)   ',' (-)  ', '               '

         ! Write the data
      DO I = 1,numNodes   
         WRITE(strFmt,'(I2)') nodes(I)%NConnections
         IF ( nodes(I)%NodeType == 1 ) THEN
            strNodeType = 'End       '
         ELSE IF ( nodes(I)%NodeType == 2 ) THEN
            strNodeType = 'Interior  '
         ELSE IF ( nodes(I)%NodeType == 3 ) THEN
            strNodeType = 'Super     '
         ELSE
            strNodeType = 'ERROR     '
         END IF
         
         WRITE( UnSum, '(1X,I5,3(2X,I10),5(2X,F10.4),2X,ES10.3,2(2X,L10),7(2X,ES10.3),2X,A10,2X,I5,' // strFmt // '(2X,I4))' ) I, nodes(I)%JointIndx, nodes(I)%JointOvrlp, nodes(I)%InpMbrIndx, nodes(I)%JointPos, nodes(I)%InpMbrDist, nodes(I)%tMG, nodes(I)%MGdensity, nodes(I)%PropWAMIT, nodes(I)%FillFlag, nodes(I)%FillDensity, nodes(I)%FillFSLoc, nodes(I)%Cd, nodes(I)%Ca, nodes(I)%R, nodes(I)%DRDZ, nodes(I)%t, strNodeType, nodes(I)%NConnections, nodes(I)%ConnectionList(1:nodes(I)%NConnections)
      END DO

      WRITE( UnSum,  '(//)' ) 
      WRITE( UnSum,  '(A8)' ) 'Elements'
      WRITE( UnSum,  '(/)' ) 
      WRITE( UnSum, '(1X,A5,2X,A5,2X,A5,5(2X,A12),2X,A12,17(2X,A12))' ) '  i  ', 'node1','node2','  Length  ', '  MGVolume  ', '  MGDensity ', 'PropWAMIT ', 'FilledFlag', 'FillDensity', '  FillFSLoc ', '  FillMass  ', '     Cd1    ', '   CdMG1  ', '     Ca1    ', '    CaMG1   ', '      R1    ', '     t1     ','     Cd2    ', '    CdMG2   ', '     Ca2    ', '    CaMG2   ', '      R2    ', '     t2     '
      WRITE( UnSum, '(1X,A5,2X,A5,2X,A5,5(2X,A12),2X,A12,17(2X,A12))' ) ' (-) ', ' (-) ',' (-) ','   (m)    ', '   (m^3)    ', '  (kg/m^3)  ', '   (-)    ', '   (-)    ', ' (kg/m^3)  ', '     (-)    ', '    (kg)    ', '     (-)    ', '    (-)   ', '     (-)    ', '     (-)    ', '     (m)    ', '     (m)    ','     (-)    ', '     (-)    ', '     (-)    ', '     (-)    ', '     (m)    ', '     (m)    '
      
      
      DO I = 1,numElements 
         
         node1   = nodes(elements(I)%Node1Indx)
         node2   = nodes(elements(I)%Node2Indx)
         IF ( ( (node1%tMG > 0 ) .AND. EqualRealNos(node2%tMG,0.0_ReKi) ) .OR. ( (node2%tMG > 0 ) .AND. EqualRealNos(node1%tMG,0.0_ReKi) ) ) THEN
            ErrStat = ErrID_Fatal
            ErrMsg  = 'If one node of an element has MG, then both must.  This is an internal code problem within HydroDyn.'
            RETURN
         END IF
         CALL GetDistance( nodes(elements(I)%Node1Indx)%JointPos, nodes(elements(I)%Node2Indx)%JointPos, l )
         
         elementVol  = ElementVolume(elements(I)%R1 + node1%tMG, elements(I)%R2 + node2%tMG, l)
         MGvolume    = elementVol  - ElementVolume(elements(I)%R1, elements(I)%R2, l)
         totalMGVol  = totalMGVol  + MGvolume
         mass_MG     = MGvolume*elements(I)%FillDens
         totalMGMass = totalMGMass + mass_MG
         CALL ElementCentroid(elements(I)%R1 + node1%tMG, elements(I)%R2 + node2%tMG, node1%JointPos, l, elements(I)%R_LToG, elemCentroid)
         
         COB         = COB         + elementVol*elemCentroid
         
         totalVol    = totalVol    + elementVol
         
         IF ( node2%JointPos(3) <= MSL2SWL ) totalDisplVol = totalDisplVol + elementVol
         
         IF ( elements(I)%MmbrFilledIDIndx > 0 ) THEN          
            filledFlag = .TRUE.
            !IF ( ( node2%JointPos(3) <= elements(I)%FillFSLoc ) .AND. ( node1%JointPos(3) <= elements(I)%FillFSLoc ) ) THEN
               fillVol       = ElementVolume(elements(I)%R1 - elements(I)%t1, elements(I)%R2 - elements(I)%t2, l)
               totalFillVol  = totalFillVol  + fillVol
               mass_fill     = elements(I)%FillDens*fillVol
               totalFillMass = totalFillMass + mass_fill
            !END IF
         ELSE
            mass_fill  = 0.0
            filledFlag = .FALSE.
         END IF
         
         WRITE( UnSum, '(1X,I5,2X,I5,2X,I5,3(2X,ES12.5),2(2X,L12),2X,ES12.5,17(2X,ES12.5))' ) I, elements(I)%Node1Indx, elements(I)%Node2Indx, l, MGvolume, node1%MGdensity, elements(I)%PropWAMIT, filledFlag, elements(I)%FillDens, elements(I)%FillFSLoc, mass_fill, elements(I)%Cd1, elements(I)%CdMG1, elements(I)%Ca1, elements(I)%CaMG1, elements(I)%R1, elements(I)%t1, elements(I)%Cd2, elements(I)%CdMG2, elements(I)%Ca2, elements(I)%CaMG2, elements(I)%R2, elements(I)%t2

      END DO   ! I = 1,numElements 
               
      
      WRITE( UnSum,  '(//)' ) 
      WRITE( UnSum,  '(A24)' ) 'Requested Member Outputs'
      WRITE( UnSum,  '(/)' ) 
      WRITE( UnSum, '(1X,A10,11(2X,A10))' ) '  Label   ', '    Xi    ',  '    Yi    ', '    Zi    ', 'InpMbrIndx', ' StartXi  ',  ' StartYi  ', ' StartZi  ', '  EndXi   ', '  EndYi   ', '  EndZi   ', '   Loc    '
      WRITE( UnSum, '(1X,A10,11(2X,A10))' ) '   (-)    ', '    (m)   ',  '    (m)   ', '    (m)   ', '   (-)    ', '   (m)    ',  '   (m)    ', '   (m)    ', '   (m)    ', '   (m)    ', '   (m)    ', '   (-)    '
      
      
      DO I = 1,NOutputs
     ! DO J=1, NMOutputs     
         !DO I=1, MOutLst(J)%NOutLoc   
         
           
               ! Get the member index and node index for this output label.  If this is not a member output the indices will return 0 with no errcode.
           ! CALL MrsnOut_GetMemberOutputInfo(WriteOutputHdr(I), NMOutputs, MOutLst, mbrIndx, nodeIndx, ErrStat, ErrMsg )
          !  IF (ErrStat > ErrID_Warning ) RETURN
           ! IF ( mbrIndx > 0 ) THEN
         tmpName =  OutParam(I)%Name
         IF (OutParam(I)%SignM == -1 ) tmpName = tmpName(2:10)
               
         IF ( ( INDEX( 'mM', tmpName(1:1) ) > 0 ) .AND. (OutParam(I)%Units /= 'INVALID' ) ) THEN
               !Get Member index and Node index
            read (tmpName(2:2),*) mbrIndx
            read (tmpName(4:4),*) nodeIndx
            m1 = MOutLst(mbrIndx)%Marker1(nodeIndx)
            m2 = MOutLst(mbrIndx)%Marker2(nodeIndx)
            s  = MOutLst(mbrIndx)%s      (nodeIndx)
         
               ! The member output is computed as a linear interpolation of the nearest two markers
            
            outLoc    = nodes(m1)%JointPos*(1-s) + nodes(m2)%JointPos*s
            WRITE( UnSum, '(1X,A10,3(2x,F10.4),2x,I10,6(2x,F10.4))' ) OutParam(I)%Name, outLoc, nodes(m1)%InpMbrIndx, nodes(m1)%JointPos, nodes(m2)%JointPos
         END IF
         
          !  END IF 
           !WRITE( UnSum, '(1X,A10,11(2X,ES10.3))' ) WriteOutputHdr(I)
        ! END DO      
      END DO
      
      
      WRITE( UnSum,  '(//)' ) 
      WRITE( UnSum,  '(A24)' ) 'Requested Joint Outputs'
      WRITE( UnSum,  '(/)' ) 
      WRITE( UnSum, '(1X,A10,5(2X,A10))' ) '  Label   ', '    Xi    ',  '    Yi    ', '    Zi    ', 'InpJointID'
      WRITE( UnSum, '(1X,A10,5(2X,A10))' ) '   (-)    ', '    (m)   ',  '    (m)   ', '    (m)   ', '   (-)    '
      
      
      DO I = 1,NOutputs
     ! DO J=1, NMOutputs     
         !DO I=1, MOutLst(J)%NOutLoc   
         
           
               ! Get the member index and node index for this output label.  If this is not a member output the indices will return 0 with no errcode.
           ! CALL MrsnOut_GetMemberOutputInfo(WriteOutputHdr(I), NMOutputs, MOutLst, mbrIndx, nodeIndx, ErrStat, ErrMsg )
          !  IF (ErrStat > ErrID_Warning ) RETURN
           ! IF ( mbrIndx > 0 ) THEN
         tmpName =  OutParam(I)%Name
         IF (OutParam(I)%SignM == -1 ) tmpName = tmpName(2:10)
               
         IF ( ( INDEX( 'jJ', tmpName(1:1) ) > 0 ) .AND. (OutParam(I)%Units /= 'INVALID') ) THEN
            
               !Get Member index and Node index
            read (tmpName(2:2),*) nodeIndx
            m1 = JOutLst(nodeIndx)%Markers(1)     
            WRITE( UnSum, '(1X,A10,3(2x,F10.4),2x,I10)' ) OutParam(I)%Name, nodes(m1)%JointPos, JOutLst(nodeIndx)%JointID
            
         END IF
         
          !  END IF 
           !WRITE( UnSum, '(1X,A10,11(2X,ES10.3))' ) WriteOutputHdr(I)
        ! END DO      
      END DO
      
      WRITE( UnSum,  '(//)' ) 
      WRITE( UnSum, '(A25)' )        'Volume Calculations (m^3)'
      WRITE( UnSum, '(A25)' )        '-------------------------'
      WRITE( UnSum, '(A26,ES12.5)' ) '  Structure Volume     :  ', totalVol
      WRITE( UnSum, '(A26,ES12.5)' ) '  Submerged Volume     :  ', totalDisplVol
      WRITE( UnSum, '(A26,ES12.5)' ) '  Marine Growth Volume :  ', totalMGVol
      WRITE( UnSum, '(A26,ES12.5)' ) '  Flooded Volume       :  ', totalFillVol
      
      
         ! Sum all buoyancy loads to the COB
         ! Do this by creating a temporary mesh which is for (0,0,0)
         
      COB = COB / totalVol   
      
         ! Write out the Center of Buoyancy (geometric center of the displaced volume)
      !WRITE( UnSum,  '(//)' ) 
      !WRITE( UnSum, '(A18)' )        'Center of Buoyancy'
      !WRITE( UnSum, '(3(2X,A10  ))' ) ' COBXi ', ' COBYi ', ' COBZi '
      !WRITE( UnSum, '(3(2X,A10  ))' ) '  (m)  ', '  (m)  ', '  (m)  '
      !WRITE( UnSum, '(3(2X,F10.3))' ) COB(1)   , COB(2)   , COB(3)
      
      CALL MeshCreate( BlankMesh        = WRP_Mesh          &
                     ,IOS               = COMPONENT_INPUT   &
                     ,Nnodes            = 1                 &
                     ,ErrStat           = ErrStat           &
                     ,ErrMess           = ErrMsg            &
                     ,Force             = .TRUE.            &
                     ,Moment            = .TRUE.            &
                     )
         ! Create the node on the mesh
            
      CALL MeshPositionNode (WRP_Mesh                              &
                              , 1                                  &
                              , (/0.0_ReKi, 0.0_ReKi, 0.0_ReKi/)   &  
                              , ErrStat                            &
                              , ErrMsg                             &
                              )
      
      IF ( ErrStat /= 0 ) RETURN
       
      
         ! Create the mesh element
      CALL MeshConstructElement (  WRP_Mesh            &
                                  , ELEMENT_POINT      &                         
                                  , ErrStat            &
                                  , ErrMsg             &
                                  , 1                  &
                                )
      CALL MeshCommit ( WRP_Mesh           &
                      , ErrStat            &
                      , ErrMsg             )
   
      IF ( ErrStat /= 0 ) RETURN
      
      WRP_Mesh%RemapFlag  = .TRUE.
      
      
         ! Attach the external distributed buoyancy loads to the distributed mesh so they can be transferred to the WRP
         
      DO J = 1, outDistribMesh%Nnodes
         
         DO I=1,6
            
            IF (I < 4 ) THEN           
               
               outDistribMesh%Force(I   ,J) = D_F_B(I,J) 
            
            ELSE
               
               outDistribMesh%Moment(I-3,J) = D_F_B(I,J)
               
            END IF
            
         END DO  ! DO I
         
      END DO ! DO J
      
 
         ! Transfer the loads from the distributed mesh to the (0,0,0) point mesh
         
      CALL AllocMapping           ( outDistribMesh, WRP_Mesh, M_L_2_P, ErrStat, ErrMsg                )
        !CALL CheckError( ErrStat, 'Message from AllocMapping HD_M_L_2_ED_P: '//NewLine//ErrMsg )
      CALL Transfer_Line2_to_Point( outDistribMesh, WRP_Mesh, M_L_2_P, ErrStat, ErrMsg, inDistribMesh )
      
      ExtBuoyancy(1:3) = WRP_Mesh%Force (:,1)
      ExtBuoyancy(4:6) = WRP_Mesh%Moment(:,1)
    
      
      
         ! Transfer the loads from the lumped mesh to the (0,0,0) point mesh
         
      DO J = 1, outLumpedMesh%Nnodes
          
         DO I=1,6
            
            IF (I < 4 ) THEN           
               
               outLumpedMesh%Force(I   ,J) = L_F_B(I,J) 
            
            ELSE
               
               outLumpedMesh%Moment(I-3,J) = L_F_B(I,J)
               
            END IF
            
         END DO  ! DO I
         
      END DO ! DO J
      
         ! Remap for the lumped to WRP mesh transfer       
      WRP_Mesh%RemapFlag  = .TRUE.
      
      CALL AllocMapping           ( outLumpedMesh, WRP_Mesh, M_P_2_P, ErrStat, ErrMsg               )
      CALL Transfer_Point_to_Point( outLumpedMesh, WRP_Mesh, M_P_2_P, ErrStat, ErrMsg, inLumpedMesh )
      
      ExtBuoyancy(1:3) = ExtBuoyancy(1:3) + WRP_Mesh%Force (:,1)
      ExtBuoyancy(4:6) = ExtBuoyancy(4:6) + WRP_Mesh%Moment(:,1)
      
      ExtBuoyancy = ExtBuoyancy / 1000.00  ! kN
      
         ! Write the buoyancy table headers and the external results

      WRITE( UnSum,  '(//)' ) 
      WRITE( UnSum, '(A45)' ) 'Buoyancy loads summed about ( 0.0, 0.0, 0.0 )'
      WRITE( UnSum, '(12x,6(2X,A20))' ) ' BuoyFxi ', ' BuoyFyi ', ' BuoyFzi ', ' BuoyMxi ', ' BuoyMyi ', ' BuoyMzi '
      WRITE( UnSum, '(12x,6(2X,A20))' ) '  (kN)   ', '  (kN)   ', '  (kN)   ', ' (kN-m)  ', ' (kN-m)  ', ' (kN-m)  '
      WRITE( UnSum, '(A12,6(2X,E20.6))') 'External:   ', ExtBuoyancy(1), ExtBuoyancy(2), ExtBuoyancy(3), ExtBuoyancy(4), ExtBuoyancy(5), ExtBuoyancy(6)
      
      
         ! Now compute internal Buoyancy
         
      DO J = 1, outDistribMesh%Nnodes
         
         DO I=1,6
            
            IF (I < 4 ) THEN           
               
               outDistribMesh%Force(I,J   ) = D_F_BF(I,J) 
               
            ELSE
               
               outDistribMesh%Moment(I-3,J) = D_F_BF(I,J)
               
            END IF
            
         END DO  ! DO I
         
      END DO ! DO J
       
      IntBuoyancy = 0.0
      CALL Transfer_Line2_to_Point( outDistribMesh, WRP_Mesh, M_L_2_P, ErrStat, ErrMsg, inDistribMesh )
      IntBuoyancy(1:3) = WRP_Mesh%Force(:,1)
      IntBuoyancy(4:6) = WRP_Mesh%Moment(:,1)
      
      
      DO J = 1, outLumpedMesh%Nnodes
         
         DO I=1,6
            
            IF (I < 4 ) THEN           
               
               outLumpedMesh%Force(I,J) = L_F_BF(I,J) 
            
            ELSE
               
               outLumpedMesh%Moment(I-3,J) = L_F_BF(I,J)
               
            END IF
            
         END DO  ! DO I
         
      END DO ! DO J 
      
      CALL Transfer_Point_to_Point( outLumpedMesh, WRP_Mesh, M_P_2_P, ErrStat, ErrMsg, inLumpedMesh )
      IntBuoyancy(1:3) = IntBuoyancy(1:3) + WRP_Mesh%Force(:,1)
      IntBuoyancy(4:6) = IntBuoyancy(4:6) + WRP_Mesh%Moment(:,1)
      
      IntBuoyancy = IntBuoyancy / 1000.00  ! kN
         ! clean up
      
      CALL MeshMapDestroy( M_P_2_P, ErrStat, ErrMsg ); IF ( ErrStat /= ErrID_None ) CALL WrScr(TRIM(ErrMsg))
     
      WRITE( UnSum, '(A12,6(2X,E20.6))') 'Internal:   ', IntBuoyancy(1), IntBuoyancy(2), IntBuoyancy(3), IntBuoyancy(4), IntBuoyancy(5), IntBuoyancy(6)
      IntBuoyancy = IntBuoyancy + ExtBuoyancy
      WRITE( UnSum, '(A12,6(2X,E20.6))') 'Total:      ', IntBuoyancy(1), IntBuoyancy(2), IntBuoyancy(3), IntBuoyancy(4), IntBuoyancy(5), IntBuoyancy(6)
      WRITE( UnSum,  '(//)' ) 
      
      
      
      
      
         ! Now compute marine growth weight at the WRP
         
      DO J = 1, outDistribMesh%Nnodes
         
         DO I=1,6
            
            IF (I < 4 ) THEN           
               
               outDistribMesh%Force(I,J) = D_F_MG(I,J) 
            
            ELSE
               
               outDistribMesh%Moment(I-3,J) = D_F_MG(I,J)
               
            END IF
            
         END DO  ! DO I
         
       END DO ! DO J
       
         
      MG_Wt = 0.0
      CALL Transfer_Line2_to_Point( outDistribMesh, WRP_Mesh, M_L_2_P, ErrStat, ErrMsg, inDistribMesh )
      MG_Wt(1:3) = WRP_Mesh%Force(:,1)
      MG_Wt(4:6) = WRP_Mesh%Moment(:,1)
      
     MG_Wt = MG_Wt / 1000.0 ! kN
     
      
      WRITE( UnSum,  '(//)' ) 
      WRITE( UnSum, '(A36)' ) 'Weight loads about ( 0.0, 0.0, 0.0 )'
      WRITE( UnSum, '(16x,6(2X,A20))' ) '  MGFxi  ', '  MGFyi  ', '  MGFzi  ', '  MGMxi  ', '  MGMyi  ', '  MGMzi  '
      WRITE( UnSum, '(16x,6(2X,A20))' ) '  (kN)   ', '  (kN)   ', '  (kN)   ', ' (kN-m)  ', ' (kN-m)  ', ' (kN-m)  '
      !WRITE( UnSum, '(A16,6(2X,E20.6))') 'Structure    :  ',  M_Wt(1),  M_Wt(2),  M_Wt(3),  M_Wt(4),  M_Wt(5),  M_Wt(6)
      WRITE( UnSum, '(A16,6(2X,E20.6))') 'Marine Growth:  ', MG_Wt(1), MG_Wt(2), MG_Wt(3), MG_Wt(4), MG_Wt(5), MG_Wt(6)
      !WRITE( UnSum, '(A16,6(2X,E20.6))') 'Filled Fluid :  ',  F_Wt(1),  F_Wt(2),  F_Wt(3),  F_Wt(4),  F_Wt(5),  F_Wt(6)
      !M_Wt = M_Wt + MG_Wt + F_Wt
      !WRITE( UnSum, '(A16,6(2X,E20.6))') 'Total        :  ',  M_Wt(1),  M_Wt(2),  M_Wt(3),  M_Wt(4),  M_Wt(5),  M_Wt(6)
      
      
      CALL MeshMapDestroy( M_L_2_P, ErrStat, ErrMsg ); IF ( ErrStat /= ErrID_None ) CALL WrScr(TRIM(ErrMsg))
      CALL MeshDestroy(WRP_Mesh, ErrStat, ErrMsg ); IF ( ErrStat /= ErrID_None ) CALL WrScr(TRIM(ErrMsg))
      
   END IF

END SUBROUTINE WriteSummaryFile

!====================================================================================================
SUBROUTINE SplitElementOnZBoundary( axis, boundary, iCurrentElement, numNodes, numElements, node1, node2, originalElement, newNode, newElement, ErrStat, ErrMsg )

   INTEGER,                  INTENT ( IN    )  :: axis
   REAL(ReKi),               INTENT ( IN    )  :: boundary
   INTEGER,                  INTENT ( IN    )  :: iCurrentElement
   INTEGER,                  INTENT ( INOUT )  :: numNodes
   TYPE(Morison_NodeType),   INTENT ( INOUT )  :: node1, node2   
   INTEGER,                  INTENT ( INOUT )  :: numElements
   TYPE(Morison_MemberType), INTENT ( INOUT )  :: originalElement
   TYPE(Morison_NodeType),   INTENT (   OUT )  :: newNode
   TYPE(Morison_MemberType), INTENT (   OUT )  :: newElement
   INTEGER,                  INTENT (   OUT )  :: ErrStat              ! returns a non-zero value when an error occurs  
   CHARACTER(*),             INTENT (   OUT )  :: ErrMsg               ! Error message if ErrStat /= ErrID_None

   INTEGER                                     :: I, J
   REAL(ReKi)                                  :: s
   INTEGER                                     :: newNodeIndx, newElementIndx
   
   ErrStat = ErrID_None
   ErrMsg = ""
   
      ! Create new node and element indices
   newNodeIndx    = numNodes + 1
   newElementIndx = numElements + 1
   
      ! find normalized distance from 1nd node to the boundary
   CALL FindInterpFactor( boundary, node1%JointPos(axis), node2%JointPos(axis), s )
   newNode = node1 ! copy all base node properties
   DO I=axis,axis+1
      J = MOD(I,3) + 1
      newNode%JointPos(J) =  node1%JointPos(J)*(1-s) + node2%JointPos(J)*s
   END DO
   newNode%JointPos(axis) =  boundary
   newNode%R_LToG         =  node1%R_LToG   
      ! Create the new  node information.  
      ! Note that the caller will determine if this is an interior node (subdivide) or an endnode (split due to MG, MSL, seabed, filled free surface)
   newNode%JointOvrlp = 0
   newNode%NConnections = 2
   newNode%ConnectionList(1) = iCurrentElement
   newNode%ConnectionList(2) = newElementIndx
   
   
      
      ! Update node2 connectivity
   DO I = 1,10  ! 10 is the maximum number of connecting elements for a node, this should probably be a parameter !! TODO
      IF ( node2%ConnectionList(I) == iCurrentElement ) THEN
         node2%ConnectionList(I) = newElementIndx
         EXIT
      END IF
   END DO
   
   
      ! Create the new element properties by first copying all the properties from the existing element
   newElement = originalElement
      ! Linearly interpolate the coef values based on depth
   originalElement%R2 = originalElement%R1 * (1-s) + originalElement%R2*s 
   newElement%R1 = originalElement%R2 
   originalElement%t2 = originalElement%t1 * (1-s) + originalElement%t2*s 
   originalElement%InpMbrDist2 = originalElement%InpMbrDist1 * (1-s) + originalElement%InpMbrDist2*s 
   newElement%t1 = originalElement%t2 
   newElement%InpMbrDist1 = originalElement%InpMbrDist2 
   
      ! The end point of the new element is set to the original end point of the existing element, then
      ! the starting point of the new element and the ending point of the existing element are set to the 
      ! newly created node
   newElement%Node2Indx      = originalElement%Node2Indx
   originalElement%Node2Indx = newNodeIndx        
   newElement%Node1Indx      = newNodeIndx
   
END SUBROUTINE SplitElementOnZBoundary


!====================================================================================================
!SUBROUTINE SplitElementsForMG(MGTop, MGBottom, numNodes, nodes, numElements, elements, ErrStat, ErrMsg)   
!
!   REAL(ReKi),               INTENT ( IN    )  :: MGTop
!   REAL(ReKi),               INTENT ( IN    )  :: MGBottom
!   INTEGER,                  INTENT ( INOUT )  :: numNodes
!   TYPE(Morison_NodeType),   INTENT ( INOUT )  :: nodes(:)   
!   INTEGER,                  INTENT ( INOUT )  :: numElements
!   TYPE(Morison_MemberType), INTENT ( INOUT )  :: elements(:)
!   INTEGER,                  INTENT (   OUT )  :: ErrStat              ! returns a non-zero value when an error occurs  
!   CHARACTER(*),             INTENT (   OUT )  :: ErrMsg               ! Error message if ErrStat /= ErrID_None
!   
!   INTEGER                                     :: I, J, K
!   INTEGER                                     :: node1Indx, node2Indx
!   TYPE(Morison_NodeType)                      :: node1, node2, newNode, newNode2
!   TYPE(Morison_MemberType)                    :: element, newElement, newElement2
!   REAL(ReKi)                                  :: zBoundary
!   INTEGER                                     :: origNumElements
!   
!   origNumElements = numElements
!   
!   DO I=1,origNumElements
!     
!      IF ( elements(I)%MGSplitState > 0 ) THEN
!         
!         node1Indx =  elements(I)%Node1Indx
!         node1 = nodes(node1Indx)
!         node2Indx =  elements(I)%Node2Indx
!         node2 = nodes(node2Indx)
!         element = elements(I)
!         
!            ! Intersects top boundary
!         IF ( elements(I)%MGSplitState == 1 ) THEN        
!            zBoundary = MGTop          
!         ELSE  ! Intersects the bottom boundary           
!            zBoundary = MGBottom          
!         END IF
!         
!         
!         CALL SplitElementOnZBoundary( zBoundary, I, numNodes, numElements, node1, node2, element, newNode, newElement, ErrStat, ErrMsg )
!         newNode%NodeType = 1 ! end node
!            ! Update the number of nodes and elements by one each
!         numNodes    = numNodes + 1
!         newNode%JointIndx = numNodes
!         numElements = numElements + 1
!         
!            ! Copy the altered nodes and elements into the master arrays
!         nodes(node1Indx)      = node1
!         nodes(node2Indx)      = node2
!         nodes(numNodes)       = newNode
!         elements(I)           = element
!         elements(numElements) = newElement
!         
!            ! If the original element spanned both marine growth boundaries, then we need to make an additional split
!         IF ( elements(I)%MGSplitState == 3 ) THEN 
!            
!            CALL SplitElementOnZBoundary( MGTop, numElements, numNodes, numElements, newNode, node2, newElement, newNode2, newElement2, ErrStat, ErrMsg )
!            newNode2%NodeType = 1 ! end node
!            newNode2%JointIndx = numNodes + 1
!               ! Copy the altered nodes and elements into the master arrays
!            nodes(numNodes)         = newNode
!            nodes(node2Indx)        = node2
!            nodes(numNodes+1)       = newNode2
!            elements(numElements)   = newElement
!            elements(numElements+1) = newElement2
!            
!               ! Update the number of nodes and elements by one each
!            numNodes    = numNodes + 1
!            
!            numElements = numElements + 1
!            
!         END IF
!      END IF 
!   END DO     
!END SUBROUTINE SplitElementsForMG

SUBROUTINE SplitElements(numNodes, nodes, numElements, elements, ErrStat, ErrMsg)   

   
   INTEGER,                  INTENT ( INOUT )  :: numNodes
   TYPE(Morison_NodeType),   INTENT ( INOUT )  :: nodes(:)   
   INTEGER,                  INTENT ( INOUT )  :: numElements
   TYPE(Morison_MemberType), INTENT ( INOUT )  :: elements(:)
   INTEGER,                  INTENT (   OUT )  :: ErrStat              ! returns a non-zero value when an error occurs  
   CHARACTER(*),             INTENT (   OUT )  :: ErrMsg               ! Error message if ErrStat /= ErrID_None
   
   INTEGER                                     :: I, J, K, iCurrent, nSplits
   REAL(ReKi)                                  :: splits(5)
   INTEGER                                     :: node1Indx, node2Indx
   TYPE(Morison_NodeType)                      :: node1, node2, newNode, newNode2
   TYPE(Morison_MemberType)                    :: element, newElement, newElement2
   REAL(ReKi)                                  :: zBoundary
   INTEGER                                     :: origNumElements
   
   
      ! Initialize ErrStat
         
   ErrStat = ErrID_None         
   ErrMsg  = "" 
   
   
   origNumElements = numElements
   
   DO I=1,origNumElements
     
      IF ( elements(I)%NumSplits > 0 ) THEN
         
         
            ! The splits are presorted from smallest Z to largest Z
         nSplits  = elements(I)%NumSplits
         splits   = elements(I)%Splits
         iCurrent = I
         
         DO J=1,nSplits
            
            node1Indx =  elements(iCurrent)%Node1Indx
            node1     = nodes(node1Indx)
            node2Indx =  elements(iCurrent)%Node2Indx
            node2     = nodes(node2Indx)
            element   = elements(iCurrent)
            
            CALL SplitElementOnZBoundary( 3, splits(J), iCurrent, numNodes, numElements, node1, node2, element, newNode, newElement, ErrStat, ErrMsg )
            
               ! Was this split due to the location of an elements free surface location crossing through the element?
            IF ( element%MmbrFilledIDIndx  /= -1 ) THEN
               IF ( EqualRealNos(element%FillFSLoc, splits(J)) )  THEN
                !  Print*, 'Switching Element to unfilled: ',element%InpMbrIndx  DEBUG< TODO, Remove 9/30/13 GJH
                  newElement%MmbrFilledIDIndx = -1
               END IF
            END IF
            
            newNode%NodeType = 1 ! end node
               ! Update the number of nodes and elements by one each
            numNodes    = numNodes + 1
            newNode%JointIndx = numNodes
            numElements = numElements + 1
         
               ! Copy the altered nodes and elements into the master arrays
            !nodes(node1Indx)      = node1
            nodes(node2Indx)      = node2
            nodes(numNodes)       = newNode
            elements(iCurrent)    = element
            elements(numElements) = newElement
            
            
            
               ! now make element = newElement by setting iCurrent to numElements
            iCurrent = numElements
            
            
         END DO           
    
      END IF 
   END DO     
END SUBROUTINE SplitElements

!====================================================================================================
!SUBROUTINE SplitElementsForWtr(MSL2SWL, Zseabed, numNodes, nodes, numElements, elements, ErrStat, ErrMsg)   
!
!   REAL(ReKi),               INTENT ( IN    )  :: MSL2SWL
!   REAL(ReKi),               INTENT ( IN    )  :: Zseabed
!   INTEGER,                  INTENT ( INOUT )  :: numNodes
!   TYPE(Morison_NodeType),   INTENT ( INOUT )  :: nodes(:)   
!   INTEGER,                  INTENT ( INOUT )  :: numElements
!   TYPE(Morison_MemberType), INTENT ( INOUT )  :: elements(:)
!   INTEGER,                  INTENT (   OUT )  :: ErrStat              ! returns a non-zero value when an error occurs  
!   CHARACTER(*),             INTENT (   OUT )  :: ErrMsg               ! Error message if ErrStat /= ErrID_None
!   
!   INTEGER                                     :: I, J, K
!   INTEGER                                     :: node1Indx, node2Indx
!   TYPE(Morison_NodeType)                      :: node1, node2, newNode, newNode2
!   TYPE(Morison_MemberType)                    :: element, newElement, newElement2
!   REAL(ReKi)                                  :: zBoundary
!   INTEGER                                     :: origNumElements
!   
!   origNumElements = numElements
!   
!   DO I=1,origNumElements
!     
!      IF ( elements(I)%WtrSplitState > 0 ) THEN
!         
!         node1Indx =  elements(I)%Node1Indx
!         node1 = nodes(node1Indx)
!         node2Indx =  elements(I)%Node2Indx
!         node2 = nodes(node2Indx)
!         element = elements(I)
!         
!            ! Intersects top boundary
!         IF ( elements(I)%WtrSplitState == 1 ) THEN        
!            zBoundary = MSL2SWL          
!         ELSE  ! Intersects the bottom boundary           
!            zBoundary = Zseabed          
!         END IF
!         
!         
!         CALL SplitElementOnZBoundary( zBoundary, I, numNodes, numElements, node1, node2, element, newNode, newElement, ErrStat, ErrMsg )
!         newNode%NodeType = 1 ! end node
!            ! Update the number of nodes and elements by one each
!         numNodes    = numNodes + 1
!         newNode%JointIndx = numNodes
!         numElements = numElements + 1
!         
!            ! Copy the altered nodes and elements into the master arrays
!         nodes(node1Indx)      = node1
!         nodes(node2Indx)      = node2
!         nodes(numNodes)       = newNode
!         elements(I)           = element
!         elements(numElements) = newElement
!         
!            ! If the original element spanned both marine growth boundaries, then we need to make an additional split
!         IF ( elements(I)%WtrSplitState == 3 ) THEN 
!            
!            CALL SplitElementOnZBoundary( MSL2SWL, numElements, numNodes, numElements, newNode, node2, newElement, newNode2, newElement2, ErrStat, ErrMsg )
!            newNode2%NodeType = 1 ! end node
!            newNode2%JointIndx = numNodes + 1
!               ! Copy the altered nodes and elements into the master arrays
!            nodes(numNodes)         = newNode
!            nodes(node2Indx)        = node2
!            nodes(numNodes+1)       = newNode2
!            elements(numElements)   = newElement
!            elements(numElements+1) = newElement2
!            
!               ! Update the number of nodes and elements by one each
!            numNodes    = numNodes + 1
!            
!            numElements = numElements + 1
!            
!         END IF
!      END IF 
!   END DO     
!END SUBROUTINE SplitElementsForWtr
!====================================================================================================
SUBROUTINE SubdivideMembers( numNodes, nodes, numElements, elements, ErrStat, ErrMsg )

   INTEGER,                  INTENT ( INOUT )  :: numNodes
   TYPE(Morison_NodeType),   INTENT ( INOUT )  :: nodes(:)   
   INTEGER,                  INTENT ( INOUT )  :: numElements
   TYPE(Morison_MemberType), INTENT ( INOUT )  :: elements(:)   
   INTEGER,                  INTENT (   OUT )  :: ErrStat              ! returns a non-zero value when an error occurs  
   CHARACTER(*),             INTENT (   OUT )  :: ErrMsg               ! Error message if ErrStat /= ErrID_None
   
   TYPE(Morison_NodeType)                      :: node1, node2, newNode
   TYPE(Morison_MemberType)                    :: element, newElement
   INTEGER                                     :: numDiv
   REAL(ReKi)                                  :: divSize(3)
   INTEGER                                     :: I, J, K
   REAL(ReKi)                                  :: memLen
   INTEGER                                     :: origNumElements
   INTEGER                                     :: node1Indx, node2Indx, elementIndx, axis
   REAL(ReKi)                                  :: start, Loc
   
      ! Initialize ErrStat
         
   ErrStat = ErrID_None         
   ErrMsg  = "" 
   
   
   origNumElements = numElements
   
   DO I=1,origNumElements
      
      element = elements(I)
      node1Indx  = element%Node1Indx
      node1       = nodes(node1Indx)     
      node2Indx   = element%Node2Indx          ! We need this index for the last sub-element
      node2       = nodes(node2Indx)
      elementIndx = I
      
      
      CALL GetDistance(node1%JointPos, node2%JointPos, memLen)
      
      
         ! If the requested division size is less then the member length, we will subdivide the member
         
      IF ( element%MDivSize < memLen ) THEN
         IF ( .NOT. ( EqualRealNos( node2%JointPos(3) , node1%JointPos(3) ) ) ) THEN
            axis  = 3
         ELSE IF ( .NOT. ( EqualRealNos( node2%JointPos(2) , node1%JointPos(2)  ) ) ) THEN       
            axis  = 2
         ELSE IF ( .NOT. ( EqualRealNos( node2%JointPos(1) , node1%JointPos(1)  ) ) ) THEN
            axis  = 1
         ELSE
            ! ERROR
         END IF
         
         start = node1%JointPos(axis)
         numDiv = CEILING( memLen / element%MDivSize  )
      
         DO K=1,3
            divSize(K) = (node2%JointPos(K) - node1%JointPos(K)) / numDiv
         END DO
      
         DO J=1,numDiv - 1
            
            loc = start + divSize(axis)*J
            CALL SplitElementOnZBoundary( axis, loc, elementIndx, numNodes, numElements, node1, node2, element, newNode, newElement, ErrStat, ErrMsg )
            newNode%NodeType = 2 ! interior node
            newNode%JointIndx = -1
               ! Copy updated node and element information to the nodes and elements arrays
            nodes(node1Indx)       = node1
            nodes(node2Indx)       = node2
            numNodes               = numNodes + 1
            numElements            = numElements + 1
            nodes(numNodes)        = newNode
            elements(elementIndx)  = element
            elements(numElements)  = newElement
            
            node1                  = newNode
            element                = newElement
            node1Indx              = numNodes
            elementIndx            = numElements 
            
            
            
            
            
            ! Create a new node
            !newNode = node2
            !
            !DO K=1,3
            !   newNode%JointPos = node1%JointPos(K) + divSize(K)*J
            !END DO
            !
            !numNodes = numNodes + 1
            !element%Node2Indx = numNodes
            !nodes(numNodes) = newNode
            !
            !   ! Create a new element
            !newElement = element
            !newElement%Node1Indx = numNodes
            !element = newElement
            !numElements = numElements + 1
         END DO
         
         !element%Node2Indx = node2Indx
         
      END IF  
      
   END DO
         
         
END SUBROUTINE SubdivideMembers         
      
SUBROUTINE CreateSuperMembers( )

 
      
         ! Determine if any of the joints flagged for overlap elimination (super member creation) satisfy the necessary requirements
      !IF ( InitInp%NJoints  > 0 ) THEN
      !
      !   DO I = 1,InitInp%NJoints
      !      
      !         ! Check #1 are there more than 2 members connected to the joint?
      !      IF ( InitInp%InpJoints(I)%JointOvrlp == 1 .AND. InitInp%InpJoints(I)%NConnections > 2) THEN
      !            ! Check #2 are there two members whose local z-axis are the same?
      !         CALL Get180Members(joint, InitInp%Joints, InitInp%Members, member1, member2)
      !         
      !         !zVect1
      !         !zVect2
      !         !dot(zVect1, zVect2)
      !         
      !      END IF
      !      
      !      
      !   END DO
      !   
      !
      !END IF
      
      
END SUBROUTINE CreateSuperMembers


!====================================================================================================
SUBROUTINE SetDepthBasedCoefs( z, NCoefDpth, CoefDpths, Cd, CdMG, Ca, CaMG )
   
   REAL(ReKi), INTENT ( IN )              :: z
   INTEGER, INTENT (IN   ) :: NCoefDpth
   TYPE(Morison_CoefDpths), INTENT (IN   )  :: CoefDpths(:)
   REAL(ReKi), INTENT (  OUT)             :: Cd
   REAL(ReKi), INTENT (  OUT)             :: CdMG
   REAL(ReKi), INTENT (  OUT)             :: Ca
   REAL(ReKi), INTENT (  OUT)             :: CaMG
   
   INTEGER                 :: I, indx1, indx2
   REAL(ReKi)              :: dd, s
   LOGICAL                 :: foundLess ! = .FALSE. bjj: this variable will have the SAVE attribute if you add the "= .FALSE." here in its declaration statement
   
   
      !Find the table entry(ies) which match the node's depth value
      ! The assumption here is that the depth table is stored from largest
      ! to smallest in depth
   
   foundLess = .FALSE.
   DO I = 1, NCoefDpth
      IF ( CoefDpths(I)%Dpth <= z .AND. .NOT. foundLess ) THEN
         indx1 = I
         foundLess = .TRUE.
      END IF
      IF ( CoefDpths(I)%Dpth >= z ) THEN
         indx2 = I
      END IF
      
   END DO
   
      ! Linearly interpolate the coef values based on depth
   !CALL FindInterpFactor( z, CoefDpths(indx1)%Dpth, CoefDpths(indx2)%Dpth, s )
      
   dd = CoefDpths(indx1)%Dpth - CoefDpths(indx2)%Dpth
   IF ( EqualRealNos(dd, 0.0_ReKi) ) THEN
      s = 0
   ELSE
      s = ( CoefDpths(indx1)%Dpth - z ) / dd
   END IF
   
   Cd   = CoefDpths(indx1)%DpthCd*(1-s) + CoefDpths(indx2)%DpthCd*s
   Ca   = CoefDpths(indx1)%DpthCa*(1-s) + CoefDpths(indx2)%DpthCa*s
   CdMG = CoefDpths(indx1)%DpthCdMG*(1-s) + CoefDpths(indx2)%DpthCdMG*s
   CaMG = CoefDpths(indx1)%DpthCaMG*(1-s) + CoefDpths(indx2)%DpthCaMG*s

END SUBROUTINE SetDepthBasedCoefs


!====================================================================================================
SUBROUTINE SetSplitNodeProperties( numNodes, nodes, numElements, elements, ErrStat, ErrMsg )   
!     This private subroutine generates the properties of nodes after the mesh has been split
!     the input data.  
!---------------------------------------------------------------------------------------------------- 

   INTEGER,                  INTENT ( IN    )  :: numNodes
   INTEGER,                  INTENT ( IN    )  :: numElements
   TYPE(Morison_MemberType), INTENT ( INOUT )  :: elements(:)
   TYPE(Morison_NodeType),   INTENT ( INOUT )  :: nodes(:)
   INTEGER,                  INTENT (   OUT )  :: ErrStat              ! returns a non-zero value when an error occurs  
   CHARACTER(*),             INTENT (   OUT )  :: ErrMsg               ! Error message if ErrStat /= ErrID_None
   
   
   INTEGER                                     :: I
   TYPE(Morison_MemberType)                    :: element
   REAL(ReKi)                                  :: dR, dz
   REAL(ReKi)                                  :: DirCos(3,3)
   
   ErrStat = ErrID_None
   ErrMsg = ""
   
   
   DO I=1,numNodes
      
      IF ( nodes(I)%NodeType /= 3 ) THEN
         
            ! End point or internal member node
            ! Super member nodes already have there properties set
            
            
         !element = elements(nodes(I)%ConnectionList(1))
         
            ! Calculate the element-level direction cosine matrix and attach it to the entry in the elements array
            
        ! CALL Morison_DirCosMtrx( nodes(element%Node1Indx)%JointPos, nodes(element%Node2Indx)%JointPos, elements(nodes(I)%ConnectionList(1))%R_LToG )
         
         element = elements(nodes(I)%ConnectionList(1))
         
         nodes(I)%R_LToG     = element%R_LToG
         
         nodes(I)%InpMbrIndx = element%InpMbrIndx
         IF ( .NOT. ( ( nodes(element%Node1Indx)%tMG > 0 ) .AND. ( nodes(element%Node2Indx)%tMG > 0 ) ) )  THEN
            nodes(element%Node1Indx)%tMG       = 0.0
            nodes(element%Node2Indx)%tMG       = 0.0
            nodes(element%Node1Indx)%MGdensity = 0.0
            nodes(element%Node2Indx)%MGdensity = 0.0
         END IF
         IF ( element%Node1Indx == I ) THEN
            
            IF ( nodes(I)%tMG > 0 ) THEN
               nodes(I)%Cd   = element%CdMG1
               nodes(I)%Ca   = element%CaMG1
            ELSE
               nodes(I)%Cd   = element%Cd1
               nodes(I)%Ca   = element%Ca1
            END IF
            
            nodes(I)%R    = element%R1
            nodes(I)%t    = element%t1
            nodes(I)%InpMbrDist = element%InpMbrDist1
         ELSE
            
            IF ( nodes(I)%tMG > 0 ) THEN
               nodes(I)%Cd   = element%CdMG2
               nodes(I)%Ca   = element%CaMG2
            ELSE
               nodes(I)%Cd   = element%Cd2
               nodes(I)%Ca   = element%Ca2
            END IF
            
            nodes(I)%R    = element%R2
            nodes(I)%t    = element%t2
            nodes(I)%InpMbrDist = element%InpMbrDist2
         END IF
         ! TODO: VERIFY THE Direction of the dz and dR calculations, 3/13/13 GJH the matlab code uses End - Start, so this should be ok.
         ! TODO: VERIFY that if dz = 0 then dRdz = 0
         CALL GetDistance( nodes(element%Node1Indx)%JointPos, nodes(element%Node2Indx)%JointPos, dz )
         dR = ( element%R2 + nodes(element%Node2Indx)%tMG ) - ( element%R1 + nodes(element%Node1Indx)%tMG )
         IF ( EqualRealNos(dR, 0.0_ReKi) ) dR = 0.0
         IF ( EqualRealNos(dz, 0.0_ReKi) ) THEN
            nodes(I)%dRdz = 0.0
         ELSE   
            nodes(I)%dRdz = dR / dz
         END IF
         
         nodes(I)%PropWAMIT = element%PropWAMIT
         
         IF ( element%MmbrFilledIDIndx /= -1 ) THEN
            nodes(I)%FillFlag  = .TRUE.
            nodes(I)%FillFSLoc    = element%FillFSLoc
            nodes(I)%FillDensity  = element%FillDens
            
         ELSE
            nodes(I)%FillFSLoc    = 0.0
            nodes(I)%FillDensity  = 0.0
            elements(nodes(I)%ConnectionList(1))%FillDens  = 0.0
            elements(nodes(I)%ConnectionList(1))%FillFSLoc = 0.0
         END IF
            
         
     
         
      END IF
      
END DO

END SUBROUTINE SetSplitNodeProperties


!====================================================================================================
!SUBROUTINE SetMemberCoefs( SimplCd, SimplCdMG, SimplCa, SimplCaMG, CoefMembers, NCoefDpth, CoefDpths, element, node1, node2 )
SUBROUTINE SetElementCoefs( SimplCd, SimplCdMG, SimplCa, SimplCaMG, CoefMembers, NCoefDpth, CoefDpths, numNodes, nodes, numElements, elements )   
!     This private subroutine generates the Cd, Ca, CdMG, and CaMG coefs for the member based on
!     the input data.  
!---------------------------------------------------------------------------------------------------- 

   REAL(ReKi),                INTENT( IN    )  :: SimplCd 
   REAL(ReKi),                INTENT( IN    )  :: SimplCdMG
   REAL(ReKi),                INTENT( IN    )  :: SimplCa
   REAL(ReKi),                INTENT( IN    )  :: SimplCaMG 
   TYPE(Morison_CoefMembers), INTENT( IN    )  :: CoefMembers(:)
   INTEGER,                   INTENT( IN    )  :: NCoefDpth
   TYPE(Morison_CoefDpths),   INTENT( IN    )  :: CoefDpths(:)
   INTEGER,                   INTENT( IN    )  :: numNodes
   INTEGER,                   INTENT( IN    )  :: numElements
   TYPE(Morison_MemberType),  INTENT( INOUT )  :: elements(:)
   TYPE(Morison_NodeType),    INTENT( IN    )  :: nodes(:)
   
   TYPE(Morison_NodeType)                      :: node1, node2
   
   INTEGER                                     :: MCoefMod
   INTEGER                                     :: I, J
   REAL(ReKi)                                  :: Cd, CdMG, Ca, CaMG
   DO I=1,numElements
      
      
      MCoefMod = elements(I)%MCoefMod
      node1    = nodes(elements(I)%Node1Indx)
      node2    = nodes(elements(I)%Node2Indx)
      
      SELECT CASE ( MCoefMod )
      
      CASE (1)
      
         elements(I)%Cd1   = SimplCd
         elements(I)%Cd2   = SimplCd
         elements(I)%Ca1   = SimplCa
         elements(I)%Ca2   = SimplCa
         elements(I)%CdMG1 = SimplCdMG
         elements(I)%CdMG2 = SimplCdMG
         elements(I)%CaMG1 = SimplCaMG
         elements(I)%CaMG2 = SimplCaMG
      
      CASE (2)
       
         CALL SetDepthBasedCoefs( node1%JointPos(3), NCoefDpth, CoefDpths, Cd, CdMG, Ca, CaMG )
         elements(I)%Cd1     = Cd
         elements(I)%Ca1     = Ca
         elements(I)%CdMG1   = CdMG
         elements(I)%CaMG1   = CaMG
         
         CALL SetDepthBasedCoefs( node2%JointPos(3), NCoefDpth, CoefDpths, Cd, CdMG, Ca, CaMG )
         elements(I)%Cd2     = Cd
         elements(I)%Ca2     = Ca
         elements(I)%CdMG2   = CdMG
         elements(I)%CaMG2   = CaMG
         
      CASE (3)
      
         J          = elements(I)%MmbrCoefIDIndx
         elements(I)%Cd1   = CoefMembers(J)%MemberCd1
         elements(I)%Cd2   = CoefMembers(J)%MemberCd2
         elements(I)%Ca1   = CoefMembers(J)%MemberCa1
         elements(I)%Ca2   = CoefMembers(J)%MemberCa2
         elements(I)%CdMG1 = CoefMembers(J)%MemberCdMG1
         elements(I)%CdMG2 = CoefMembers(J)%MemberCdMG2
         elements(I)%CaMG1 = CoefMembers(J)%MemberCaMG1
         elements(I)%CaMG2 = CoefMembers(J)%MemberCaMG2
         
      END SELECT
   
      
   END DO
   
END SUBROUTINE SetElementCoefs


SUBROUTINE SetHeaveCoefs( NJoints, NHvCoefs, HeaveCoefs, numNodes, nodes, numElements, elements )

   INTEGER,                    INTENT( IN    )  :: NJoints
   INTEGER,                    INTENT( IN    )  :: NHvCoefs
   TYPE(Morison_HeaveCoefType),INTENT( IN    )  :: HeaveCoefs(:)
   INTEGER,                    INTENT( IN    )  :: numNodes
   INTEGER,                    INTENT( IN    )  :: numElements
   TYPE(Morison_MemberType),   INTENT( INOUT )  :: elements(:)
   TYPE(Morison_NodeType),     INTENT( INOUT )  :: nodes(:)
   
   TYPE(Morison_NodeType)                       :: node1, node2
   
   INTEGER                                     :: I, J
   
   DO I=1,numNodes
      
      IF ( nodes(I)%JointHvIDIndx > 0 .AND. nodes(I)%JointIndx > 0 .AND. nodes(I)%JointIndx <= NJoints) THEN
         nodes(I)%HvCd = HeaveCoefs(nodes(I)%JointHvIDIndx)%HvCd
         nodes(I)%HvCa = HeaveCoefs(nodes(I)%JointHvIDIndx)%HvCa
      ELSE
         nodes(I)%HvCd = 0.0
         nodes(I)%HvCa = 0.0
      END IF
      
      !node1    = nodes(elements(I)%Node1Indx)
      !node2    = nodes(elements(I)%Node2Indx)
      
   END DO
   
END SUBROUTINE SetHeaveCoefs


SUBROUTINE SetNodeMG( numMGDepths, MGDepths, numNodes, nodes )

   INTEGER,                      INTENT( IN    )  :: numMGDepths
   TYPE(Morison_MGDepthsType),   INTENT( IN    )  :: MGDepths(:)
   INTEGER,                      INTENT( IN    )  :: numNodes
   TYPE(Morison_NodeType),       INTENT( INOUT )  :: nodes(:)

   INTEGER                                     :: I, J
   REAL(ReKi)              :: z
   INTEGER                 :: indx1, indx2
   REAL(ReKi)              :: dd, s
   LOGICAL                 :: foundLess = .FALSE.
   
   DO I=1,numNodes
      
         !Find the table entry(ies) which match the node's depth value
      ! The assumption here is that the depth table is stored from largest
      ! to smallest in depth
      z = nodes(I)%JointPos(3)
      foundLess = .FALSE.
      indx1 = 0
      indx2 = 0
      DO J = 1, numMGDepths
         IF ( MGDepths(J)%MGDpth <= z .AND. .NOT. foundLess ) THEN
            indx1 = J
            
            foundLess = .TRUE.
         END IF
         IF ( MGDepths(J)%MGDpth >= z ) THEN
            indx2 = J
         END IF
      
      END DO
      IF ( indx2 == 0 .OR. .NOT. foundLess ) THEN
         !Not at a marine growth depth
         nodes(I)%tMG       = 0.0
         nodes(I)%MGdensity = 0.0
      ELSE
         ! Linearly interpolate the coef values based on depth
         !CALL FindInterpFactor( z, CoefDpths(indx1)%Dpth, CoefDpths(indx2)%Dpth, s )
      
         dd = MGDepths(indx1)%MGDpth - MGDepths(indx2)%MGDpth
         IF ( EqualRealNos(dd, 0.0_ReKi) ) THEN
            s = 0
         ELSE
            s = ( MGDepths(indx1)%MGDpth - z ) / dd
         END IF
         nodes(I)%tMG       = MGDepths(indx1)%MGThck*(1-s) + MGDepths(indx2)%MGThck*s
         nodes(I)%MGdensity = MGDepths(indx1)%MGDens*(1-s) + MGDepths(indx2)%MGDens*s
      END IF
      
   END DO
   

END SUBROUTINE SetNodeMG



SUBROUTINE SetElementFillProps( numFillGroups, filledGroups, numElements, elements )

   INTEGER,                       INTENT( IN    )  :: numFillGroups
   TYPE(Morison_FilledGroupType), INTENT( IN    )  :: filledGroups(:)
   INTEGER,                       INTENT( IN    )  :: numElements
   TYPE(Morison_MemberType),      INTENT( INOUT )  :: elements(:)  
   
   INTEGER                                         :: I, J
   
   DO I=1,numElements
      
      
      IF ( elements(I)%MmbrFilledIDIndx > 0 ) THEN
         
         elements(I)%FillDens     =   filledGroups(elements(I)%MmbrFilledIDIndx)%FillDens
         elements(I)%FillFSLoc    =   filledGroups(elements(I)%MmbrFilledIDIndx)%FillFSLoc
      ELSE
         elements(I)%FillDens     =   0.0
         elements(I)%FillFSLoc    =   0.0
      END IF
      
     
      
   END DO
   
   
END SUBROUTINE SetElementFillProps

!SUBROUTINE CreateLumpedMarkers( numNodes, nodes, numElements, elements, numLumpedMarkers, lumpedMarkers, ErrStat, ErrMsg )
!
!   INTEGER,                   INTENT( IN    )  :: numNodes
!   INTEGER,                   INTENT( IN    )  :: numElements
!   TYPE(Morison_MemberType),  INTENT( IN    )  :: elements(:)  
!   TYPE(Morison_NodeType),    INTENT( IN    )  :: nodes(:)
!   INTEGER,                   INTENT(   OUT )  :: numLumpedMarkers
!   TYPE(Morison_NodeType), ALLOCATABLE,    INTENT(   OUT )  :: lumpedMarkers(:)
!   INTEGER,                  INTENT (   OUT )  :: ErrStat              ! returns a non-zero value when an error occurs  
!   CHARACTER(*),             INTENT (   OUT )  :: ErrMsg               ! Error message if ErrStat /= ErrID_None
!   
!   INTEGER                                     :: I, J, count
!   TYPE(Morison_MemberType)                    :: element
!   
!   numLumpedMarkers = 0
!   
!      ! Count how many distributed markers we need to create by looping over the nodes
!   DO I=1,numNodes
!      IF ( nodes(I)%NodeType == 1 .AND. nodes(I)%JointOvrlp == 0 ) THEN
!            ! end of a member that was not a part of super member creation
!         numLumpedMarkers = numLumpedMarkers + 1
!      END IF
!   END DO
!   
!      ! Allocate the array for the distributed markers
!   ALLOCATE ( lumpedMarkers(numLumpedMarkers), STAT = ErrStat )
!   IF ( ErrStat /= ErrID_None ) THEN
!      ErrMsg  = ' Error allocating space for the lumped load markers array.'
!      ErrStat = ErrID_Fatal
!      RETURN
!   END IF  
!   count = 1   
!   DO I=1,numNodes
!      
!      IF ( nodes(I)%NodeType == 1 .AND. nodes(I)%JointOvrlp == 0) THEN
!         
!         element = elements(nodes(I)%ConnectionList(1))
!         
!         IF ( element%Node1Indx == I ) THEN
!            lumpedMarkers(count)%Cd   = element%Cd1
!            lumpedMarkers(count)%CdMG = element%CdMG1
!            lumpedMarkers(count)%Ca   = element%Ca1
!            lumpedMarkers(count)%CaMG = element%CaMG1
!            lumpedMarkers(count)%R    = element%R1
!            lumpedMarkers(count)%t    = element%t1
!         ELSE
!            lumpedMarkers(count)%Cd   = element%Cd2
!            lumpedMarkers(count)%CdMG = element%CdMG2
!            lumpedMarkers(count)%Ca   = element%Ca2
!            lumpedMarkers(count)%CaMG = element%CaMG2
!            lumpedMarkers(count)%R    = element%R2
!            lumpedMarkers(count)%t    = element%t2
!         END IF
!         
!         lumpedMarkers(count)%PropWAMIT = element%PropWAMIT
!         lumpedMarkers(count)%tMG       = nodes(I)%tMG
!         lumpedMarkers(count)%MGdensity = nodes(I)%MGdensity
!         
!         
!            ! Compute all initialization forces now so we have access to the element information
!            
!         !IF ( element%PropWAMIT == .FALSE. ) THEN
!         !   
!         !      ! Member is not modeled with WAMIT
!         !   CALL LumpedBuoyancy( )             
!         !   CALL LumpedMGLoads( )       
!         !   CALL LumpedDynPressure( )
!         !   CALL LumpedAddedMass( )
!         !   CALL LumpedAddedMassMG( )
!         !   CALL LumpedAddedMassFlood( )  ! Do we actually compute this??? TODO
!         !   
!         !END IF
!         !   
!         !   ! These are the only two loads we compute at initialization if the member is modeled with WAMIT
!         !CALL LumpedDragConst( ) 
!         !CALL LumpedFloodedBuoyancy( )  
!         
!         
!         count = count + 1        
!      
!      END IF
!      
!   END DO
!   
!END SUBROUTINE CreateLumpedMarkers


SUBROUTINE SplitMeshNodes( numNodes, nodes, numElements, elements, numSplitNodes, splitNodes, ErrStat, ErrMsg )

   INTEGER,                   INTENT( IN    )  :: numNodes
   INTEGER,                   INTENT( IN    )  :: numElements
   TYPE(Morison_MemberType),  INTENT( INOUT )  :: elements(:)
   TYPE(Morison_NodeType),    INTENT( IN    )  :: nodes(:)
   INTEGER,                   INTENT(   OUT )  :: numSplitNodes
   TYPE(Morison_NodeType), ALLOCATABLE,    INTENT(   OUT )  :: splitNodes(:)
   INTEGER,                  INTENT (   OUT )  :: ErrStat              ! returns a non-zero value when an error occurs  
   CHARACTER(*),             INTENT (   OUT )  :: ErrMsg               ! Error message if ErrStat /= ErrID_None
   
   INTEGER                                     :: I, J, splitNodeIndx
   TYPE(Morison_MemberType)                    :: element
   TYPE(Morison_NodeType)                      :: node1, node2, newNode
   
   
      ! Initialize ErrStat
         
   ErrStat = ErrID_None         
   ErrMsg  = "" 
   
   numSplitNodes = 0
   
      ! Count how many distributed markers we need to create by looping over the nodes
   DO I=1,numNodes
      IF ( nodes(I)%NodeType == 1 ) THEN
            ! Nodes at the end of members get one node for each connecting member
         numSplitNodes = numSplitNodes + nodes(I)%NConnections     
      ELSE      
          ! Internal nodes and super member nodes only get one node
         numSplitNodes = numSplitNodes + 1
      END IF
   END DO
   
      ! Allocate the array for the distributed markers
   ALLOCATE ( splitNodes(numSplitNodes), STAT = ErrStat )
   IF ( ErrStat /= ErrID_None ) THEN
      ErrMsg  = ' Error allocating space for split nodes array.'
      ErrStat = ErrID_Fatal
      RETURN
   END IF  
   
   splitNodes(1:numNodes)    = nodes(1:numNodes)
   
   IF ( numSplitNodes > numNodes ) THEN
      
      splitNodeIndx = numNodes + 1 
   
      DO I=1,numElements
         ! Loop over elements in the processed mesh and create additional nodes/markers at the end of elements if that node connects to other elements
         node1 = splitnodes(elements(I)%Node1Indx)
         node2 = splitnodes(elements(I)%Node2Indx)
      
         IF (node1%NodeType == 1 ) THEN ! end node
            IF ( node1%NConnections > 1 ) THEN
                  !create new node by copying the old one
               newNode = node1
               newNode%NConnections = 1
               splitnodes(splitNodeIndx) = newNode
               splitnodes(elements(I)%Node1Indx)%NConnections = node1%NConnections - 1
               !set the new node as the first node of this element
               elements(I)%Node1Indx = splitNodeIndx
               splitNodeIndx = splitNodeIndx + 1
               !NOTE: the node connection list entries are now bogus!!!!
            END IF
      
         END IF
      
         IF (node2%NodeType == 1 ) THEN ! end node
            IF ( node2%NConnections > 1 ) THEN
                  !create new node by copying the old one
               newNode = node2
               newNode%NConnections = 1
               splitnodes(splitNodeIndx) = newNode
               splitnodes(elements(I)%Node2Indx)%NConnections = node2%NConnections - 1
               !set the new node as the first node of this element
               elements(I)%Node2Indx = splitNodeIndx
               splitNodeIndx = splitNodeIndx + 1
               !NOTE: the node connection list entries are now bogus!!!!
            END IF
      
         END IF
      
      END DO
      
      ! Fix connections
      DO J = 1,numSplitNodes
         splitnodes(J)%NConnections = 0
      END DO
      
      DO I = 1,numElements
        
            
         DO J = 1,numSplitNodes
            IF ( elements(I)%Node1Indx == J ) THEN
               splitnodes(J)%NConnections = splitnodes(J)%NConnections + 1
               splitnodes(J)%ConnectionList(splitnodes(J)%NConnections) = I
            END IF 
            IF ( elements(I)%Node2Indx == J ) THEN
               splitnodes(J)%NConnections = splitnodes(J)%NConnections + 1
               splitnodes(J)%ConnectionList(splitnodes(J)%NConnections) = I
            END IF 
         END DO
      END DO
      
  END IF 
   
END SUBROUTINE SplitMeshNodes



SUBROUTINE GenerateLumpedLoads( nodeIndx, sgn, node, gravity, MSL2SWL, densWater, NStepWave, WaveDynP0, dragConst, F_DP, F_B, F_BF, ErrStat, ErrMsg )

   INTEGER,                 INTENT( IN    )     ::  nodeIndx
   REAL(ReKi),              INTENT( IN    )     ::  sgn
   TYPE(Morison_NodeType),  INTENT( IN    )     ::  node
   REAL(ReKi),              INTENT( IN    )     ::  gravity
   REAL(ReKi),              INTENT( IN    )     ::  MSL2SWL
   REAL(ReKi),              INTENT( IN    )     ::  densWater
   INTEGER,                 INTENT( IN    )     ::  NStepWave
   REAL(ReKi),              INTENT( IN    )     ::  WaveDynP0(:,:)
   REAL(ReKi),ALLOCATABLE,  INTENT(   OUT )     ::  F_DP(:,:)
   REAL(ReKi),              INTENT(   OUT )     ::  F_B(6)
   REAL(ReKi),              INTENT(   OUT )     ::  F_BF(6)
   REAL(ReKi),              INTENT(   OUT )     ::  dragConst
   INTEGER,                 INTENT(   OUT )     ::  ErrStat              ! returns a non-zero value when an error occurs  
   CHARACTER(*),            INTENT(   OUT )     ::  ErrMsg               ! Error message if ErrStat /= ErrID_None

   REAL(ReKi)                                   ::  k(3)
 
   
      ! Initialize ErrStat
         
   ErrStat = ErrID_None         
   ErrMsg  = "" 
   
   
   IF (.NOT. node%PropWAMIT ) THEN
   
      k =  sgn * node%R_LToG(:,3)
      
      CALL LumpDynPressure( nodeIndx, k, node%R, node%tMG, NStepWave, WaveDynP0, F_DP, ErrStat, ErrMsg)
      
           
      CALL LumpBuoyancy( sgn, densWater, node%R, node%tMG, node%JointPos(3) - MSL2SWL, node%R_LToG, gravity, F_B  ) 
                    
       
      ! This one is tricky because we need to calculate a signed volume which is the signed sum of all connecting elements and then split the 
      ! result across all the connecting nodes.
      !CALL LumpAddedMass() 
   
   ELSE
      
      ALLOCATE ( F_DP(0:NStepWave, 6), STAT = ErrStat )
      IF ( ErrStat /= ErrID_None ) THEN
         ErrMsg  = ' Error allocating distributed dynamic pressure loads array.'
         ErrStat = ErrID_Fatal
         RETURN
      END IF  
      F_DP = 0.0
      F_B  = 0.0
   END IF
   
   
   CALL LumpDragConst( densWater, node%Cd, node%R, node%tMG, dragConst ) 
   
   
   IF ( node%FillDensity /= 0.0 ) THEN
      
      CALL LumpFloodedBuoyancy( sgn, node%FillDensity, node%R, node%t, node%FillFSLoc, node%JointPos(3) - MSL2SWL, node%R_LToG, gravity, F_BF )      
      
   END IF
   

END SUBROUTINE GenerateLumpedLoads



SUBROUTINE CreateLumpedMesh( densWater, gravity, MSL2SWL, wtrDpth, NStepWave, WaveDynP0, numNodes, nodes, numElements, elements, &
                                  numLumpedMarkers, lumpedMeshIn, lumpedMeshOut, lumpedToNodeIndx, L_An,        &
                                  L_F_B, L_F_DP, L_F_BF, L_AM_M, L_dragConst, &
                                  ErrStat, ErrMsg )

   REAL(ReKi),                             INTENT( IN    )  ::  densWater
   REAL(ReKi),                             INTENT( IN    )  ::  gravity
   REAL(ReKi),                             INTENT( IN    )  ::  MSL2SWL
   REAL(ReKi),                             INTENT( IN    )  ::  wtrDpth
   INTEGER,                                INTENT( IN    )  ::  NStepWave
   REAL(ReKi),                             INTENT( IN    )  ::  WaveDynP0(0:,:)
   INTEGER,                                INTENT( IN    )  ::  numNodes
   INTEGER,                                INTENT( IN    )  ::  numElements
   TYPE(Morison_MemberType),               INTENT( IN    )  ::  elements(:)
   TYPE(Morison_NodeType),                 INTENT( INOUT )  ::  nodes(:)
   INTEGER,                                INTENT(   OUT )  ::  numLumpedMarkers
   !TYPE(Morison_NodeType), ALLOCATABLE,    INTENT(   OUT )  ::  lumpedMarkers(:)
   TYPE(MeshType),                         INTENT(   OUT )  ::  lumpedMeshIn
   TYPE(MeshType),                         INTENT(   OUT )  ::  lumpedMeshOut 
   INTEGER, ALLOCATABLE,                   INTENT(   OUT )  ::  lumpedToNodeIndx(:)
   REAL(ReKi),ALLOCATABLE,                 INTENT(   OUT)   ::  L_An(:,:)                         ! The signed/summed end cap Area x k of all connected members at a common joint
   REAL(ReKi),ALLOCATABLE,                 INTENT(   OUT)   ::  L_F_B(:,:)                      ! Buoyancy force associated with the member
   REAL(ReKi),ALLOCATABLE,                 INTENT(   OUT)   ::  L_F_DP(:,:,:)                     ! Dynamic pressure force
   REAL(ReKi),ALLOCATABLE,                 INTENT(   OUT)   ::  L_F_BF(:,:)                     ! Flooded buoyancy force
   REAL(ReKi),ALLOCATABLE,                 INTENT(   OUT)   ::  L_AM_M(:,:,:)                   ! Added mass of member
   REAL(ReKi),ALLOCATABLE,                 INTENT(   OUT)   ::  L_dragConst(:)                   ! 
   INTEGER,                                INTENT(   OUT )  ::  ErrStat              ! returns a non-zero value when an error occurs  
   CHARACTER(*),                           INTENT(   OUT )  ::  ErrMsg               ! Error message if ErrStat /= ErrID_None
   
             
   INTEGER                    ::  I, J, count
   TYPE(Morison_MemberType)   ::  element
   TYPE(Morison_NodeType)     ::  node, node1, node2
   REAL(ReKi)                 ::  L, sgn
   REAL(ReKi)                 ::  k(3)
   REAL(ReKi)                 ::  z0
   REAL(ReKi),ALLOCATABLE     ::  F_DP(:,:)
   REAL(ReKi)                 ::  F_B(6)
   REAL(ReKi)                 ::  F_BF(6)
   REAL(ReKi)                 ::  AM(6,6)
   REAL(ReKi)                 ::  dragConst
   
   
   INTEGER, ALLOCATABLE       :: nodeToLumpedIndx(:)
   INTEGER, ALLOCATABLE       :: commonNodeLst(:)
   LOGICAL, ALLOCATABLE       :: usedJointList(:)
   INTEGER                    :: nCommon
   REAL(ReKi)                 :: CA
   REAL(ReKi)                 :: AMfactor
   REAL(ReKi)                 :: An(3)
   REAL(ReKi)                 :: AM11, AM22, AM33
   REAL(ReKi)                 :: f1, f2
   
   
      ! Initialize ErrStat
         
   ErrStat = ErrID_None         
   ErrMsg  = "" 
   
   
   numLumpedMarkers = 0
   z0                = -(wtrDpth + MSL2SWL) ! The total sea depth is the still water depth of the seabed + the mean sea level to still water level offset
   
      ! CA is the added mass coefficient for three dimensional bodies in infinite fluid (far from boundaries) The default value is 2/Pi
   !CA = 0.0 ! TODO: GJH 9/26/13 This needs to be wired up to heave coefs2.0 / Pi   
   
   AMfactor = 2.0 * densWater * Pi / 3.0
   
      ! Count how many lumped markers we need to create by looping over the nodes
      
   DO I=1,numNodes
      
      IF ( (nodes(I)%NodeType == 3) .OR. ( nodes(I)%NodeType == 1 .AND. nodes(I)%JointOvrlp == 0 )  ) THEN
      
            numLumpedMarkers = numLumpedMarkers + 1
      
      END IF
      
   END DO
   
   
      ! Create the input and output meshes associated with lumped loads
      
   CALL MeshCreate( BlankMesh      = lumpedMeshIn           &
                     ,IOS          = COMPONENT_INPUT        &
                     ,Nnodes       = numLumpedMarkers       &
                     ,ErrStat      = ErrStat                &
                     ,ErrMess      = ErrMsg                 &
                     ,TranslationDisp = .TRUE.             &
                     ,Orientation     = .TRUE.                 &
                     ,TranslationVel  = .TRUE.              &
                     ,RotationVel     = .TRUE.              &
                     ,TranslationAcc  = .TRUE.              &
                     ,RotationAcc     = .TRUE.     )

    
   
   
   !   ! Allocate the array for the lumped markers
   !   
   !ALLOCATE ( lumpedMarkers(numLumpedMarkers), STAT = ErrStat )
   !IF ( ErrStat /= ErrID_None ) THEN
   !   ErrMsg  = ' Error allocating space for the lumped load markers array.'
   !   ErrStat = ErrID_Fatal
   !   RETURN
   !END IF  
   
   ALLOCATE ( commonNodeLst(10), STAT = ErrStat )
   IF ( ErrStat /= ErrID_None ) THEN
      ErrMsg  = ' Error allocating space for the commonNodeLst array.'
      ErrStat = ErrID_Fatal
      RETURN
   END IF 
   commonNodeLst = -1
   
   ALLOCATE ( usedJointList(numNodes), STAT = ErrStat )
   IF ( ErrStat /= ErrID_None ) THEN
      ErrMsg  = ' Error allocating space for the UsedJointList array.'
      ErrStat = ErrID_Fatal
      RETURN
   END IF  
   
   usedJointList = .FALSE.
   
   ALLOCATE ( lumpedToNodeIndx(numLumpedMarkers), STAT = ErrStat )
   IF ( ErrStat /= ErrID_None ) THEN
      ErrMsg  = ' Error allocating space for the lumped index array.'
      ErrStat = ErrID_Fatal
      RETURN
   END IF  
   
   ALLOCATE ( nodeToLumpedIndx(numNodes), STAT = ErrStat )
   IF ( ErrStat /= ErrID_None ) THEN
      ErrMsg  = ' Error allocating space for the lumped index array.'
      ErrStat = ErrID_Fatal
      RETURN
   END IF  
   
   
   
   ALLOCATE ( L_F_B( 6, numLumpedMarkers ), STAT = ErrStat )
   IF ( ErrStat /= ErrID_None ) THEN
      ErrMsg  = ' Error allocating space for the lumped buoyancy forces/moments array.'
      ErrStat = ErrID_Fatal
      RETURN
   END IF
   L_F_B = 0.0
   
   ALLOCATE ( L_An( 3, numLumpedMarkers ), STAT = ErrStat )
   IF ( ErrStat /= ErrID_None ) THEN
      ErrMsg  = ' Error allocating space for the L_An array.'
      ErrStat = ErrID_Fatal
      RETURN
   END IF
   L_An = 0.0
   
   ALLOCATE ( L_F_DP( 0:NStepWave, 6, numLumpedMarkers ), STAT = ErrStat )
   IF ( ErrStat /= ErrID_None ) THEN
      ErrMsg  = ' Error allocating space for the lumped dynamic pressure forces/moments array.'
      ErrStat = ErrID_Fatal
      RETURN
   END IF
    L_F_DP = 0.0
   
   ALLOCATE ( L_F_BF( 6, numLumpedMarkers ), STAT = ErrStat )
   IF ( ErrStat /= ErrID_None ) THEN
      ErrMsg  = ' Error allocating space for the lumped buoyancy due to flooding forces/moments array.'
      ErrStat = ErrID_Fatal
      RETURN
   END IF
   L_F_BF = 0.0
   
   ALLOCATE ( L_AM_M( 6, 6, numLumpedMarkers ), STAT = ErrStat )
   IF ( ErrStat /= ErrID_None ) THEN
      ErrMsg  = ' Error allocating space for the lumped member added mass.'
      ErrStat = ErrID_Fatal
      RETURN
   END IF
   L_AM_M = 0.0
      
   ALLOCATE ( L_dragConst( numLumpedMarkers ), STAT = ErrStat )
   IF ( ErrStat /= ErrID_None ) THEN
      ErrMsg  = ' Error allocating space for the lumped drag constants.'
      ErrStat = ErrID_Fatal
      RETURN
   END IF
   L_dragConst = 0.0
   
   ! Loop over nodes to create all loads on the resulting markers except for the buoyancy loads
   ! For the buoyancy loads, loop over the elements and then apply one half of the resulting value
   ! to each of the interior element nodes but the full value to an end node.  This means that an internal member node will receive 1/2 of its
   ! load from element A and 1/2 from element B.  If it is the end of a member it will simply receive
   ! the element A load.
   
   count = 1 
   
   DO I=1,numNodes
      
          ! exclude internal member nodes and end nodes which were connected to a joint made into a super member
          
      IF ( (nodes(I)%NodeType == 3) .OR. ( nodes(I)%NodeType == 1 .AND. nodes(I)%JointOvrlp == 0 )  ) THEN
         
            lumpedToNodeIndx(count) = I
            nodeToLumpedIndx(I) = count
               
               ! If this is a super member node, then generate the lumped loads now, otherwise save it for the loop over elements
               
            IF ( nodes(I)%NodeType == 3 ) THEN
               
            END IF
            

            
            
               ! Create the node on the mesh
            
            CALL MeshPositionNode (lumpedMeshIn          &
                              , count                    &
                              , nodes(I)%JointPos        &  ! this info comes from FAST
                              , ErrStat                  &
                              , ErrMsg                   &
                              ) !, transpose(nodes(I)%R_LToG)          )
            IF ( ErrStat /= 0 ) THEN
               RETURN
            END IF 
         
               ! Create the mesh element
         
            CALL MeshConstructElement (  lumpedMeshIn   &
                                  , ELEMENT_POINT      &
                                  
                                  , ErrStat            &
                                  , ErrMsg  &
                                  , count                  &
                                              )
            count = count + 1    
         
         
      END IF
            
   END DO
   
   
      ! Loop over nodes again in order to created lumped added mass 
      
   DO I=1,numNodes
      
      IF ( .NOT. nodes(I)%PropWAMIT ) THEN
      
      
            ! Determine bounds checking based on what load we are calculating, 
            ! This is for AM_M
         IF ( nodes(I)%JointPos(3) <= MSL2SWL .AND. nodes(I)%JointPos(3) >= z0 ) THEN
         
               ! exclude internal member nodes and end nodes which were connected to a joint made into a super member
      
         
               
                  ! If this is a super member node, then generate the lumped loads now, otherwise save it for the loop over elements
               
               IF ( nodes(I)%NodeType == 3 ) THEN
               
               ELSE
            
                  IF ( nodes(I)%JointIndx /= -1 ) THEN  ! TODO: MAYBE THIS SHOULD CHECK JointOvrlp value instead!!
               
                     ! Have we already set the added mass for this node?
                  IF ( .NOT. usedJointList(nodes(I)%JointIndx) ) THEN
                  
                     nCommon = 0
                     AM11    = 0.0
                     AM22    = 0.0
                     AM33    = 0.0
                     
                     DO J=1,numNodes
                     
                           ! must match joint index but also cannot be modeled using WAMIT
                        IF ( ( nodes(I)%JointIndx == nodes(J)%JointIndx ) .AND. (.NOT. nodes(J)%PropWAMIT ) )THEN
                           ! DEBUG.  TODO  Remove this
                           IF ( ( nodes(I)%JointPos(1) /= nodes(J)%JointPos(1) ) .OR. ( nodes(I)%JointPos(2) /= nodes(J)%JointPos(2) ) .OR. ( nodes(I)%JointPos(3) /= nodes(J)%JointPos(3) ) ) THEN 
                              CALL WrScr('Error with lumped joint forces')
                           END IF 
                           nCommon = nCommon + 1
                           commonNodeLst(nCommon) = J
                        
                              ! Compute the signed volume of this member
                           f1 = (nodes(J)%R+nodes(J)%tMG)*(nodes(J)%R+nodes(J)%tMG)*(nodes(J)%R+nodes(J)%tMG) 
                           
                           IF ( .NOT. nodes(J)%FillFlag ) THEN
                            
                              AM11 =  AM11 + AMfactor*nodes(J)%R_LToG(1,1)*f1*nodes(J)%HvCa
                              AM22 =  AM22 + AMfactor*nodes(J)%R_LToG(2,2)*f1*nodes(J)%HvCa
                              AM33 =  AM33 + AMfactor*nodes(J)%R_LToG(3,3)*f1*nodes(J)%HvCa
                           
                           ELSE
                           
                              f2 = (nodes(J)%R-nodes(J)%t)*(nodes(J)%R-nodes(J)%t)*(nodes(J)%R-nodes(J)%t)                       
                              AM11 =  AM11 + AMfactor*nodes(J)%R_LToG(1,1)*( f1 - f2  )*nodes(J)%HvCa
                              AM22 =  AM22 + AMfactor*nodes(J)%R_LToG(2,2)*( f1 - f2  )*nodes(J)%HvCa
                              AM33 =  AM33 + AMfactor*nodes(J)%R_LToG(3,3)*( f1 - f2  )*nodes(J)%HvCa
                           
                           END IF
                        
                        END IF
                     
                     END DO
                  
                  
                        ! Divide the added mass equally across all connected markers but make sure it is positive in magnitude
                     
                     DO J=1,nCommon
                     
                        IF ( nodes(I)%JointPos(3) <= MSL2SWL .AND.     nodes(I)%JointPos(3) >= z0 ) THEN
                        
                           L_AM_M(1,1,nodeToLumpedIndx(commonNodeLst(J))) = ABS(AM11) / nCommon
                           L_AM_M(2,2,nodeToLumpedIndx(commonNodeLst(J))) = ABS(AM22) / nCommon
                           L_AM_M(3,3,nodeToLumpedIndx(commonNodeLst(J))) = ABS(AM33) / nCommon
                        
                        ELSE
                           ! Should we ever land in here?
                           L_AM_M(1,1,nodeToLumpedIndx(commonNodeLst(J))) = 0.0
                           L_AM_M(2,2,nodeToLumpedIndx(commonNodeLst(J))) = 0.0
                           L_AM_M(3,3,nodeToLumpedIndx(commonNodeLst(J))) = 0.0
                        
                        END IF
                     
                     END DO
                  
                     usedJointList(nodes(I)%JointIndx) = .TRUE.
                  END IF
               
                  END IF
              END IF 
              
   
         
         END IF   ! ( nodes(I)%JointPos(3) <= MSL2SWL .AND. nodes(I)%JointPos(3) >= z0 )
      
      END IF
            
   END DO   ! I=1,numNodes
   
   
 
       ! Loop over nodes again in order to create lumped heave drag. 
       
   usedJointList = .FALSE.   
   commonNodeLst = -1
   
   DO I=1,numNodes
      
     
      
            ! Determine bounds checking based on what load we are calculating, 
            ! This is for AM_M
         IF ( nodes(I)%JointPos(3) <= MSL2SWL .AND. nodes(I)%JointPos(3) >= z0 ) THEN
         
               ! exclude internal member nodes and end nodes which were connected to a joint made into a super member
      
         
               
                  ! If this is a super member node, then generate the lumped loads now, otherwise save it for the loop over elements
               
               IF ( nodes(I)%NodeType == 3 ) THEN
               
               ELSE
            
                  IF ( nodes(I)%JointIndx /= -1 ) THEN  ! TODO: MAYBE THIS SHOULD CHECK JointOvrlp value instead!!
               
                     ! Have we already set the added mass for this node?
                  IF ( .NOT. usedJointList(nodes(I)%JointIndx) ) THEN
                  
                     nCommon   = 0
                     An        = 0.0
                    
                     
                     DO J=1,numNodes
                     
                           ! must match joint index but also cannot be modeled using WAMIT
                        IF  ( nodes(I)%JointIndx == nodes(J)%JointIndx ) THEN
                           ! DEBUG.  TODO  Remove this
                           IF ( ( nodes(I)%JointPos(1) /= nodes(J)%JointPos(1) ) .OR. ( nodes(I)%JointPos(2) /= nodes(J)%JointPos(2) ) .OR. ( nodes(I)%JointPos(3) /= nodes(J)%JointPos(3) ) ) THEN 
                              CALL WrScr('Error with lumped joint forces')
                           END IF 
                           nCommon = nCommon + 1
                           commonNodeLst(nCommon) = J
                        
                              ! Compute the signed area*outward facing normal of this member
                           sgn = 1.0
                           
                           element = elements(nodes(J)%ConnectionList(1))
                           
                           IF ( element%Node1Indx == J ) THEN
                              sgn = -1.0                                ! Local coord sys points into element at starting node, so flip sign of local z vector
                           ELSE IF ( element%Node2Indx == J ) THEN
                              sgn = 1.0                                 ! Local coord sys points out of element at ending node, so leave sign of local z vector
                           ELSE
                              ErrMsg  = 'Internal Error in CreateLumpedMesh: could not find element node index match.'
                              ErrStat = ErrID_FATAL
                              RETURN
                           END IF
                           
                           An = An + sgn*nodes(J)%R_LtoG(:,3)*Pi*(nodes(J)%R+nodes(J)%tMG)**2
                                         
                        END IF
                     
                     END DO
                  
                     nodes(I)%NConnectPreSplit = nCommon
                        ! Divide the added mass equally across all connected markers but make sure it is positive in magnitude
                     
                     DO J=1,nCommon
                     
                        IF ( nodes(I)%JointPos(3) <= MSL2SWL .AND.     nodes(I)%JointPos(3) >= z0 ) THEN
                        
                           L_An(:,nodeToLumpedIndx(commonNodeLst(J))) = An                        
                        
                        ELSE
                           ! Should we ever land in here?
                           L_An(:,nodeToLumpedIndx(commonNodeLst(J))) = 0.0
                        
                        END IF
                     
                     END DO
                  
                     usedJointList(nodes(I)%JointIndx) = .TRUE.
                  END IF
               
                  END IF
              END IF 
              
   
         
         END IF   ! ( nodes(I)%JointPos(3) <= MSL2SWL .AND. nodes(I)%JointPos(3) >= z0 )
      
     
            
   END DO   ! I=1,numNodes
   
   
      ! Loop over elements and identify those end nodes which have a JointOvrlp option of 0.
      
   DO I=1,numElements
      
      element = elements(I)
      node1   = nodes(element%Node1Indx)
      node2   = nodes(element%Node2Indx)
      
      CALL GetDistance( node1%JointPos, node2%JointPos, L )
          
      IF ( node1%NodeType == 1 .AND.  node1%JointOvrlp == 0 ) THEN
         
            !Process Lumped loads for this node
         node = node1
         sgn = 1.0
         IF ( node%JointPos(3) <= MSL2SWL .AND. node%JointPos(3) >= z0 ) THEN
            CALL GenerateLumpedLoads( element%Node1Indx, sgn, node, gravity, MSL2SWL, densWater, NStepWave, WaveDynP0, dragConst, F_DP, F_B, F_BF, ErrStat, ErrMsg )
            L_F_DP(:, :, nodeToLumpedIndx(element%Node1Indx)) = F_DP
            L_F_B (:, nodeToLumpedIndx(element%Node1Indx))    = F_B
            L_dragConst(nodeToLumpedIndx(element%Node1Indx))  = dragConst
            
         ELSE
            L_F_DP(:, :, nodeToLumpedIndx(element%Node1Indx)) = 0.0
            L_F_B (:, nodeToLumpedIndx(element%Node1Indx))    = 0.0
            L_dragConst(nodeToLumpedIndx(element%Node1Indx))  = 0.0
            
         END IF
         IF ( node%FillFlag ) THEN
            IF ( node%JointPos(3) <= node%FillFSLoc  .AND. node%JointPos(3) >= z0 ) THEN
               L_F_BF(:, nodeToLumpedIndx(element%Node1Indx))    = F_BF
            ELSE
               L_F_BF(:, nodeToLumpedIndx(element%Node1Indx))    = 0.0
            END IF
         ELSE
            L_F_BF(:, nodeToLumpedIndx(element%Node1Indx))       = 0.0
         END IF
         
         
      ENDIF
      
      
      IF ( node2%NodeType == 1 .AND.  node2%JointOvrlp == 0 ) THEN
         
            !Process Lumped loads for this node
         node = node2
         sgn = -1.0
         
            ! Generate the loads regardless of node location, and then make the bounds check per load type because the range is different
         CALL GenerateLumpedLoads( element%Node2Indx, sgn, node, gravity, MSL2SWL, densWater, NStepWave, WaveDynP0, dragConst, F_DP, F_B, F_BF, ErrStat, ErrMsg )
         IF ( node%JointPos(3) <= MSL2SWL .AND. node%JointPos(3) >= z0 ) THEN
            
            L_F_DP(:, :, nodeToLumpedIndx(element%Node2Indx)) = F_DP
            L_F_B (:, nodeToLumpedIndx(element%Node2Indx))    = F_B
            L_dragConst(nodeToLumpedIndx(element%Node2Indx))  = dragConst
            
         ELSE
            L_F_DP(:, :, nodeToLumpedIndx(element%Node2Indx)) = 0.0
            L_F_B (:, nodeToLumpedIndx(element%Node2Indx))    = 0.0
            L_dragConst(nodeToLumpedIndx(element%Node2Indx))  = 0.0
            
         END IF
         IF ( node%FillFlag ) THEN
            IF ( node%JointPos(3) <= node%FillFSLoc   .AND. node%JointPos(3) >= z0 ) THEN
               L_F_BF(:, nodeToLumpedIndx(element%Node2Indx))    = F_BF
            ELSE
               L_F_BF(:, nodeToLumpedIndx(element%Node2Indx))    = 0.0
            END IF
         ELSE
            L_F_BF(:, nodeToLumpedIndx(element%Node2Indx))       = 0.0
         END IF
      ENDIF
      
      
       
      
      IF ( ErrStat /= 0 ) THEN
            RETURN
      END IF 
      
      
   END DO    
      
   
   CALL MeshCommit ( lumpedMeshIn   &
                      , ErrStat            &
                      , ErrMsg             )
   
   IF ( ErrStat /= 0 ) THEN
         RETURN
   END IF 
   
      ! Initialize the inputs
   DO I=1,lumpedMeshIn%Nnodes
      lumpedMeshIn%Orientation(:,:,I) = lumpedMeshIn%RefOrientation(:,:,I)
   END DO
   lumpedMeshIn%TranslationDisp = 0.0
   lumpedMeshIn%TranslationVel  = 0.0
   lumpedMeshIn%RotationVel     = 0.0
   lumpedMeshIn%TranslationAcc  = 0.0
   lumpedMeshIn%RotationAcc     = 0.0
   
   CALL MeshCopy (   SrcMesh      = lumpedMeshIn            &
                     ,DestMesh     = lumpedMeshOut          &
                     ,CtrlCode     = MESH_SIBLING           &
                     ,IOS          = COMPONENT_OUTPUT       &
                     ,ErrStat      = ErrStat                &
                     ,ErrMess      = ErrMsg                 &
                     ,Force        = .TRUE.                 &
                     ,Moment       = .TRUE.                 )
   
   lumpedMeshIn%RemapFlag  = .TRUE.
   lumpedMeshOut%RemapFlag = .TRUE.
   
   
END SUBROUTINE CreateLumpedMesh
                                  

SUBROUTINE CreateDistributedMesh( densWater, gravity, MSL2SWL, wtrDpth, NStepWave, WaveAcc0, WaveDynP0, numNodes, nodes, numElements, elements, &
                                  numDistribMarkers,  distribMeshIn, distribMeshOut, distribToNodeIndx,        &
                                  D_F_I, D_F_B, D_F_DP, D_F_MG, D_F_BF, D_AM_M, D_AM_MG, D_AM_F, D_dragConst, &
                                  ErrStat, ErrMsg )

   REAL(ReKi),                             INTENT( IN    )  ::  densWater
   REAL(ReKi),                             INTENT( IN    )  ::  gravity
   REAL(ReKi),                             INTENT( IN    )  ::  MSL2SWL
   REAL(ReKi),                             INTENT( IN    )  ::  wtrDpth
   INTEGER,                                INTENT( IN    )  ::  NStepWave
   REAL(ReKi),                             INTENT( IN    )  ::  WaveAcc0(0:,:,:)
   REAL(ReKi),                             INTENT( IN    )  ::  WaveDynP0(0:,:)
   INTEGER,                                INTENT( IN    )  ::  numNodes
   INTEGER,                                INTENT( IN    )  ::  numElements
   TYPE(Morison_MemberType),               INTENT( IN    )  ::  elements(:)
   TYPE(Morison_NodeType),                 INTENT( IN    )  ::  nodes(:)
   INTEGER,                                INTENT(   OUT )  ::  numDistribMarkers
   !TYPE(Morison_NodeType), ALLOCATABLE,    INTENT(   OUT )  ::  distribMarkers(:)
   TYPE(MeshType),                         INTENT(   OUT )  ::  distribMeshIn
   TYPE(MeshType),                         INTENT(   OUT )  ::  distribMeshOut 
   INTEGER, ALLOCATABLE,                   INTENT(   OUT )  ::  distribToNodeIndx(:)
   REAL(ReKi),ALLOCATABLE,                 INTENT(   OUT)   ::  D_F_I(:,:,:)                      ! Inertial force associated with the member
   REAL(ReKi),ALLOCATABLE,                 INTENT(   OUT)   ::  D_F_B(:,:)                      ! Buoyancy force associated with the member
   REAL(ReKi),ALLOCATABLE,                 INTENT(   OUT)   ::  D_F_DP(:,:,:)                     ! Dynamic pressure force
   REAL(ReKi),ALLOCATABLE,                 INTENT(   OUT)   ::  D_F_MG(:,:)                     ! Marine growth weight
   REAL(ReKi),ALLOCATABLE,                 INTENT(   OUT)   ::  D_F_BF(:,:)                     ! Flooded buoyancy force
   REAL(ReKi),ALLOCATABLE,                 INTENT(   OUT)   ::  D_AM_MG(:,:,:)                  ! Added mass of marine growth
   REAL(ReKi),ALLOCATABLE,                 INTENT(   OUT)   ::  D_AM_M(:,:,:)                   ! Added mass of member
   REAL(ReKi),ALLOCATABLE,                 INTENT(   OUT)   ::  D_AM_F(:,:,:)                   ! Added mass of flooded fluid
   REAL(ReKi),ALLOCATABLE,                 INTENT(   OUT)   ::  D_dragConst(:)                   ! 
   INTEGER,                                INTENT(   OUT )  ::  ErrStat              ! returns a non-zero value when an error occurs  
   CHARACTER(*),                           INTENT(   OUT )  ::  ErrMsg               ! Error message if ErrStat /= ErrID_None
   
            
   
   INTEGER                    ::  I, J, count, node2Indx
   INTEGER                    ::  elementWaterState
   TYPE(Morison_MemberType)   ::  element
   TYPE(Morison_NodeType)     ::  node1, node2
   REAL(ReKi)                 ::  L
   REAL(ReKi)                 ::  k(3)
   REAL(ReKi),ALLOCATABLE     ::  F_I(:,:)
   REAL(ReKi),ALLOCATABLE     ::  F_DP(:,:)
   REAL(ReKi)                 ::  F_B(6)
   REAL(ReKi)                 ::  F_BF(6)
   REAL(ReKi)                 ::  z0
   INTEGER, ALLOCATABLE       :: nodeToDistribIndx(:)
   
   numDistribMarkers = 0
   z0                = -(wtrDpth + MSL2SWL) ! The total sea depth is the still water depth of the seabed + the mean sea level to still water level offset
   
      ! Count how many distributed markers we need to create by looping over the nodes
      
   DO I=1,numNodes
      
      IF ( nodes(I)%NodeType /= 3 ) THEN ! exclude super member nodes
            
         numDistribMarkers = numDistribMarkers + 1
      
      END IF
      
   END DO
   
   
      ! Create the input and output meshes associated with distributed loads
      
   CALL MeshCreate( BlankMesh      = distribMeshIn            &
                     ,IOS          = COMPONENT_INPUT        &
                     ,Nnodes       = numDistribMarkers      &
                     ,ErrStat      = ErrStat                &
                     ,ErrMess      = ErrMsg                 &
                     ,TranslationDisp = .TRUE.              &
                     ,Orientation     = .TRUE.              &
                     ,TranslationVel  = .TRUE.              &
                     ,RotationVel     = .TRUE.              &
                     ,TranslationAcc  = .TRUE.              &
                     ,RotationAcc     = .TRUE.               )

    
   
   
      ! Allocate the array for the distributed markers
      
   !ALLOCATE ( distribMarkers(numDistribMarkers), STAT = ErrStat )
   !IF ( ErrStat /= ErrID_None ) THEN
   !   ErrMsg  = ' Error allocating space for the distributed load markers array.'
   !   ErrStat = ErrID_Fatal
   !   RETURN
   !END IF  
   
   ALLOCATE ( distribToNodeIndx(numDistribMarkers), STAT = ErrStat )
   IF ( ErrStat /= ErrID_None ) THEN
      ErrMsg  = ' Error allocating space for the distributed index array.'
      ErrStat = ErrID_Fatal
      RETURN
   END IF  
   
   ALLOCATE ( nodeToDistribIndx(numNodes), STAT = ErrStat )
   IF ( ErrStat /= ErrID_None ) THEN
      ErrMsg  = ' Error allocating space for the distributed index array.'
      ErrStat = ErrID_Fatal
      RETURN
   END IF  
   
   ALLOCATE ( D_F_I( 0:NStepWave, 6, numDistribMarkers ), STAT = ErrStat )
   IF ( ErrStat /= ErrID_None ) THEN
      ErrMsg  = ' Error allocating space for the distributed intertial forces/moments array.'
      ErrStat = ErrID_Fatal
      RETURN
   END IF
   D_F_I = 0.0
   
   ALLOCATE ( D_F_B( 6, numDistribMarkers ), STAT = ErrStat )
   IF ( ErrStat /= ErrID_None ) THEN
      ErrMsg  = ' Error allocating space for the distributed buoyancy forces/moments array.'
      ErrStat = ErrID_Fatal
      RETURN
   END IF
   D_F_B = 0.0
   
   ALLOCATE ( D_F_DP( 0:NStepWave, 6, numDistribMarkers ), STAT = ErrStat )
   IF ( ErrStat /= ErrID_None ) THEN
      ErrMsg  = ' Error allocating space for the distributed dynamic pressure forces/moments array.'
      ErrStat = ErrID_Fatal
      RETURN
   END IF
   D_F_DP = 0.0
   
   ALLOCATE ( D_F_MG( 6, numDistribMarkers ), STAT = ErrStat )
   IF ( ErrStat /= ErrID_None ) THEN
      ErrMsg  = ' Error allocating space for the distributed marine growth weight forces/moments array.'
      ErrStat = ErrID_Fatal
      RETURN
   END IF
   D_F_MG = 0.0
   
   ALLOCATE ( D_F_BF( 6, numDistribMarkers ), STAT = ErrStat )
   IF ( ErrStat /= ErrID_None ) THEN
      ErrMsg  = ' Error allocating space for the distributed buoyancy due to flooding forces/moments array.'
      ErrStat = ErrID_Fatal
      RETURN
   END IF
   D_F_BF = 0.0
   
   ALLOCATE ( D_AM_M( 6, 6, numDistribMarkers ), STAT = ErrStat )
   IF ( ErrStat /= ErrID_None ) THEN
      ErrMsg  = ' Error allocating space for the distributed member added mass.'
      ErrStat = ErrID_Fatal
      RETURN
   END IF
   D_AM_M = 0.0
   
   ALLOCATE ( D_AM_MG( 6, 6, numDistribMarkers ), STAT = ErrStat )
   IF ( ErrStat /= ErrID_None ) THEN
      ErrMsg  = ' Error allocating space for the distributed added mass of marine growth.'
      ErrStat = ErrID_Fatal
      RETURN
   END IF
   D_AM_MG = 0.0
   
   ALLOCATE ( D_AM_F( 6, 6, numDistribMarkers ), STAT = ErrStat )
   IF ( ErrStat /= ErrID_None ) THEN
      ErrMsg  = ' Error allocating space for the distributed added mass of flooded fluid.'
      ErrStat = ErrID_Fatal
      RETURN
   END IF
   D_AM_F = 0.0
   
   ALLOCATE ( D_dragConst( numDistribMarkers ), STAT = ErrStat )
   IF ( ErrStat /= ErrID_None ) THEN
      ErrMsg  = ' Error allocating space for the distributed drag constants.'
      ErrStat = ErrID_Fatal
      RETURN
   END IF
   D_dragConst = 0.0
   
   ! Loop over nodes to create all loads on the resulting markers except for the buoyancy loads
   ! For the buoyancy loads, loop over the elements and then apply one half of the resulting value
   ! to each of the interior element nodes but the full value to an end node.  This means that an internal member node will receive 1/2 of its
   ! load from element A and 1/2 from element B.  If it is the end of a member it will simply receive
   ! the element A load.
   
   count = 1 
   
   DO I=1,numNodes
      
      IF ( nodes(I)%NodeType /= 3 ) THEN
         
            ! End point or internal member node
            
            ! Find the node index for the other end of this element
         IF ( nodes(I)%NodeType == 1 ) THEN
            element = elements(nodes(I)%ConnectionList(1))
            IF ( element%Node1Indx == I ) THEN
               node2Indx = element%Node2Indx
            ELSE
               node2Indx = element%Node1Indx
            END IF
         ELSE
            node2Indx    = -1
         END IF
         
            ! Need to see if this node is connected to an element which goes above MSL2SWL or below Seabed.
         IF ( node2Indx > 0 ) THEN
            IF ( nodes(node2Indx)%JointPos(3) > MSL2SWL ) THEN
               elementWaterState = 1
            ELSE IF  ( nodes(node2Indx)%JointPos(3) < z0 ) THEN
               elementWaterState = 2
            ELSE
               elementWaterState = 0
            END IF
         ELSE
            elementWaterState = 0
         END IF
         
         !CALL GetDistance( element
         !   ! Compute all initialization forces now so we have access to the element information
         !   
          IF ( .NOT. nodes(I)%PropWAMIT ) THEN
            
                ! Member is not modeled with WAMIT
            
            k =  nodes(I)%R_LToG(:,3)
            
            IF ( nodes(I)%JointPos(3) <= MSL2SWL .AND. nodes(I)%JointPos(3) >= z0 ) THEN
               CALL DistrDynPressure( I, nodes(I)%R_LToG, nodes(I)%R, nodes(I)%tMG, nodes(I)%dRdz, NStepWave, WaveDynP0, F_DP, ErrStat, ErrMsg)
               D_F_DP(:,:,count) = F_DP
               CALL DistrBuoyancy2( densWater, nodes(I)%R, nodes(I)%tMG, nodes(I)%dRdz, nodes(I)%JointPos(3) - MSL2SWL, nodes(I)%R_LToG, gravity, F_B  ) 
               D_F_B(:,count)    = F_B
               
               
               IF ( elementWaterState == 0 ) THEN
                     ! Element is in the water
                  CALL DistrInertialLoads( I, densWater, nodes(I)%Ca, nodes(I)%R, nodes(I)%tMG, k, NStepWave, WaveAcc0, F_I, ErrStat, ErrMsg  )       
                  D_F_I(:,:,count)  = F_I          
               
                  CALL DistrAddedMass( densWater, nodes(I)%Ca, nodes(I)%R_LToG, nodes(I)%R, nodes(I)%tMG, D_AM_M(:,:,count) )   
               ELSE
                     ! Element is out of the water
                  D_F_I(:,:,count)  = 0.0
                  D_AM_M(:,:,count) = 0.0
               END IF
               
            ELSE 
               ! NOTE: Everything was initialized to zero so this isn't really necessary. GJH 9/24/13
               D_F_I(:,:,count)  = 0.0
               D_F_DP(:,:,count) = 0.0
               D_AM_M(:,:,count) = 0.0
               D_F_B(:,count)    = 0.0
            END IF
            
            IF ( ( nodes(I)%JointPos(3) >= z0 ) .AND. (elementWaterState /= 2 ) ) THEN
                  ! if the node is at or above the seabed then the element is in the water
               CALL DistrMGLoads( nodes(I)%MGdensity, gravity, nodes(I)%R, nodes(I)%tMG, D_F_MG(:,count) )            
               CALL DistrAddedMassMG( nodes(I)%MGdensity, nodes(I)%R, nodes(I)%tMG, D_AM_MG(:,:,count) )
            ELSE
               D_F_MG(:,count)   = 0.0
               D_AM_MG(:,:,count)= 0.0
            END IF
            
         END IF      ! IF ( .NOT. nodes(I)%PropWAMIT )
            
            ! These are the only two loads we compute at initialization if the member is modeled with WAMIT
         IF ( ( nodes(I)%JointPos(3) <= MSL2SWL .AND. nodes(I)%JointPos(3) >= z0 ) .AND.  ( elementWaterState == 0 )  )THEN   
               ! element is in the water
            CALL DistrDragConst( densWater, nodes(I)%Cd, nodes(I)%R, nodes(I)%tMG, D_dragConst(count) ) 
         ELSE
            D_dragConst(count) = 0.0
         END IF
         
         IF ( nodes(I)%FillFlag ) THEN
            IF ( nodes(I)%JointPos(3) <= nodes(I)%FillFSLoc   .AND. nodes(I)%JointPos(3) >= z0 ) THEN
               
               CALL DistrFloodedBuoyancy2( nodes(I)%FillDensity, nodes(I)%FillFSLoc, nodes(I)%R, nodes(I)%t, nodes(I)%dRdZ, nodes(I)%JointPos(3) - MSL2SWL, nodes(I)%R_LToG, gravity, F_BF )
               D_F_BF(:,count  ) = F_BF
               
                  ! different check for filled element
               IF ( node2Indx > 0 ) THEN
                  IF ( nodes(node2Indx)%JointPos(3) > nodes(I)%FillFSLoc ) THEN
                     elementWaterState = 1
                  ELSE IF  ( nodes(node2Indx)%JointPos(3) < z0 ) THEN
                     elementWaterState = 2
                  ELSE
                     elementWaterState = 0
                  END IF
               ELSE
                  elementWaterState = 0
               END IF
               
               IF (elementWaterState == 0 ) THEN
                  CALL DistrAddedMassFlood( nodes(I)%FillDensity, nodes(I)%R, nodes(I)%t, D_AM_F(:,:,count) )
               ELSE
                  D_AM_F(:,:,count) = 0.0
               END IF
               
            ELSE
               ! NOTE: Everything was initialized to zero so this isn't really necessary. GJH 9/24/13
               D_AM_F(:,:,count) = 0.0
               D_F_BF(:,count  ) = 0.0
            END IF      
         ELSE
               D_AM_F(:,:,count) = 0.0
               D_F_BF(:,count  ) = 0.0
         END IF
         
         
         
            ! Create the node on the mesh
            
         CALL MeshPositionNode (distribMeshIn           &
                              , count                   &
                              , nodes(I)%JointPos       &  ! this info comes from FAST
                              , ErrStat                 &
                              , ErrMsg                  &
                              ) !, transpose(nodes(I)%R_LToG )     )
         IF ( ErrStat /= 0 ) THEN
            RETURN
         END IF 
         
         distribToNodeIndx(count) = I
         nodeToDistribIndx(I) = count
         count = count + 1    
         
      END IF
      
   END DO
   
   
   DO I=1,numElements
   
       
         ! Create the mesh element
         
      CALL MeshConstructElement (  distribMeshIn   &
                                  , ELEMENT_LINE2       &                                 
                                  , ErrStat            &
                                  , ErrMsg  &
                                  , nodeToDistribIndx(elements(I)%Node1Indx)                  &
                                  , nodeToDistribIndx(elements(I)%Node2Indx)                )
      
      IF ( ErrStat /= 0 )    RETURN
      
   !========================================================================================================================
   !  The following section of code was used to determine distributed buoyancy using a different technique.  It is preserved
   !  here in case we want to return to this approach.
   !   
   !    element = elements(I) 
   !   node1   = nodes(element%Node1Indx)
   !   node2   = nodes(element%Node2Indx)
   !   
   !   CALL GetDistance( node1%JointPos, node2%JointPos, L )
   !   
   !   IF ( .NOT. element%PropWAMIT ) THEN
   !      
   !         !TODO How to determine when to calc distributed buoyancy if part of the element is not in the water?
   !      IF ( ( node1%JointPos(3) <= MSL2SWL .AND. node1%JointPos(3) >= z0 ) .AND. ( node2%JointPos(3) <= MSL2SWL .AND. node2%JointPos(3) >= z0 ) ) THEN 
   !         
   !         CALL DistrBuoyancy( L, densWater, element%R1, node1%tMG, node1%JointPos(3) - MSL2SWL, element%R2, node2%tMG, node2%JointPos(3) - MSL2SWL, element%R_LToG, gravity, F_B  ) 
   !         
   !      
   !            ! push the load to the markers at the
   !         
   !         IF ( node1%NodeType == 1 ) THEN
   !               ! Apply full force to an end point
   !            D_F_B(:,nodeToDistribIndx(element%Node1Indx)) = F_B
   !         
   !         ELSE
   !               ! Apply 1/2 of the force to an interior point
   !            DO J=1,6
   !               D_F_B(J,nodeToDistribIndx(element%Node1Indx)) = D_F_B(J,nodeToDistribIndx(element%Node1Indx)) + F_B(J)*0.5
   !            END DO
   !         
   !         END IF
   !      
   !         IF ( node2%NodeType == 1 ) THEN
   !               ! Apply full force to an end point
   !            D_F_B(:,nodeToDistribIndx(element%Node2Indx)) = F_B
   !         
   !         ELSE
   !         
   !               ! Apply 1/2 of the force to an interior point
   !            DO J=1,6
   !               D_F_B(J,nodeToDistribIndx(element%Node2Indx)) = D_F_B(J,nodeToDistribIndx(element%Node2Indx)) +F_B(J)*0.5
   !            END DO
   !         
   !         END IF
   !         
   !      ELSE
   !         D_F_B(:,nodeToDistribIndx(element%Node1Indx)) = 0.0
   !         D_F_B(:,nodeToDistribIndx(element%Node2Indx)) = 0.0
   !      END IF
   !      
   !   END IF
   !   
   !   
   !   IF ( element%MmbrFilledIDIndx /= -1 ) THEN
   !      IF ( ( node1%JointPos(3) <= element%FillFSLoc .AND. node1%JointPos(3) >= z0 ) .AND. ( node2%JointPos(3) <= element%FillFSLoc .AND. node2%JointPos(3) >= z0 ) ) THEN 
   !         CALL DistrFloodedBuoyancy( L, element%FillDens, element%FillFSLoc, element%R1, element%t1, node1%JointPos(3) - MSL2SWL, element%R2, element%t2, node2%JointPos(3) - MSL2SWL, element%R_LToG, gravity, F_BF )
   !      
   !            ! push the load to the markers at the
   !         
   !         IF ( node1%NodeType == 1 ) THEN
   !               ! Apply full force to an end point
   !            D_F_BF(:,nodeToDistribIndx(element%Node1Indx)) = F_BF
   !         
   !         ELSE
   !               ! Apply 1/2 of the force to an interior point
   !            DO J=1,6
   !               D_F_BF(J,nodeToDistribIndx(element%Node1Indx)) = D_F_BF(J,nodeToDistribIndx(element%Node1Indx)) + F_BF(J)*0.5
   !            END DO
   !         
   !         END IF
   !      
   !         IF ( node2%NodeType == 1 ) THEN
   !               ! Apply full force to an end point
   !            D_F_BF(:,nodeToDistribIndx(element%Node2Indx)) = F_BF
   !         
   !         ELSE
   !         
   !               ! Apply 1/2 of the force to an interior point
   !            DO J=1,6
   !               D_F_BF(J,nodeToDistribIndx(element%Node2Indx)) = D_F_BF(J,nodeToDistribIndx(element%Node2Indx)) + F_BF(J)*0.5
   !            END DO
   !         
   !         END IF
   !      ELSE
   !         D_F_BF(:,nodeToDistribIndx(element%Node1Indx)) = 0.0
   !         D_F_BF(:,nodeToDistribIndx(element%Node2Indx)) = 0.0
   !      END IF
   !      
   !   END IF
   !
   !   End of alternate buoyancy calculation approach
   !========================================================================================================================
   

      
   END DO
   
   
   CALL MeshCommit ( distribMeshIn   &
                      , ErrStat            &
                      , ErrMsg             )
   
   IF ( ErrStat /= 0 ) THEN
         RETURN
   END IF 
   
      ! Initialize the inputs
   DO I=1,distribMeshIn%Nnodes
      distribMeshIn%Orientation(:,:,I) = distribMeshIn%RefOrientation(:,:,I)
   END DO
   distribMeshIn%TranslationDisp = 0.0
   distribMeshIn%TranslationVel  = 0.0
   distribMeshIn%RotationVel     = 0.0
   distribMeshIn%TranslationAcc  = 0.0
   distribMeshIn%RotationAcc     = 0.0
   
   CALL MeshCopy (    SrcMesh      = distribMeshIn &
                     ,DestMesh     = distribMeshOut         &
                     ,CtrlCode     = MESH_SIBLING           &
                     ,IOS          = COMPONENT_OUTPUT       &
                     ,ErrStat      = ErrStat                &
                     ,ErrMess      = ErrMsg                 &
                     ,Force        = .TRUE.                 &
                     ,Moment       = .TRUE.                 )

   distribMeshIn%RemapFlag  = .TRUE.
   distribMeshOut%RemapFlag = .TRUE.
   
END SUBROUTINE CreateDistributedMesh


!====================================================================================================
SUBROUTINE Morison_ProcessMorisonGeometry( InitInp, ErrStat, ErrMsg )
!     This public subroutine process the input geometry and parameters and eliminates joint overlaps,  
!     sub-divides members, sets joint-level properties, etc.
!----------------------------------------------------------------------------------------------------  

      ! Passed variables
   
   TYPE(Morison_InitInputType),   INTENT( INOUT )   :: InitInp              ! the Morison initialization data 
   !TYPE(Morison_ParameterType),   INTENT( INOUT )   :: p                    ! tge Morison parameter data
   INTEGER,                       INTENT(   OUT )   :: ErrStat              ! returns a non-zero value when an error occurs  
   CHARACTER(*),                  INTENT(   OUT )   :: ErrMsg               ! Error message if ErrStat /= ErrID_None

  
      ! Local variables
         
   INTEGER                                      :: I, J, j1, j2, tempINT                    ! generic integer for counting
   TYPE(Morison_JointType)                      :: joint1, joint2                                   
   Real(ReKi)                                   :: z1
   Real(ReKi)                                   :: z2
   Real(ReKi)                                   :: d
   INTEGER                                      :: temp
   INTEGER                                      :: prop1Indx, prop2Indx, node1Indx, node2Indx
   INTEGER                                      :: maxNodes        = 0
   INTEGER                                      :: maxElements     = 0
   INTEGER                                      :: maxSuperMembers = 0
   TYPE(Morison_NodeType)                       :: node1, node2, tempNode
   TYPE(Morison_MemberPropType)                 :: propSet
   INTEGER                                      :: numSplitNodes
   TYPE(Morison_NodeType),ALLOCATABLE           :: splitNodes(:)
   LOGICAL                                      :: doSwap
   
      ! Initialize ErrStat
         
   ErrStat = ErrID_None         
   ErrMsg  = "" 
   
   
   IF ( InitInp%NMembers > 0 ) THEN
      
      
         ! Determine the maximum number of nodes,  elements, and super members which might be generated for the simulation mesh
      CALL GetMaxSimQuantities( InitInp%NMGDepths, InitInp%MGTop, InitInp%MGBottom, InitInp%MSL2SWL, -InitInp%WtrDpth, InitInp%FilledGroups, InitInp%NJoints, InitInp%InpJoints, InitInp%NMembers, InitInp%InpMembers, maxNodes, maxElements, maxSuperMembers )
  
  
      ! Create a worse case size for the number of nodes and number of elements that will be generated for the simulation
      ! marine growth split + super member split + member subdivision all creates new nodes
         
      ! marine growth split + member subdivision creates new elements
      
      ! Create a worse case size for the number of super members
      
         ! 1) Let's start by generating a mirror of the input mesh (joints and members) as the initial version of the simulation mesh
         ! In doing so, create the initial mapping between the input mesh and this current version of the simulation mesh
         
         
         ! Allocate memory for Joint-related arrays
         
      InitInp%NNodes = InitInp%NJoints
      
      ALLOCATE ( InitInp%Nodes(maxNodes), STAT = ErrStat )
      IF ( ErrStat /= ErrID_None ) THEN
         ErrMsg  = ' Error allocating space for Nodes array.'
         ErrStat = ErrID_Fatal
         RETURN
      END IF    
          
      
      DO I = 1,InitInp%NNodes
         ! Copy all necessary data from the input joints to these node data structures
         InitInp%Nodes(I)%JointPos       = InitInp%InpJoints(I)%JointPos
         InitInp%Nodes(I)%JointHvIDIndx  = InitInp%InpJoints(I)%JointHvIDIndx
         InitInp%Nodes(I)%JointOvrlp     = InitInp%InpJoints(I)%JointOvrlp
         InitInp%Nodes(I)%NConnections   = InitInp%InpJoints(I)%NConnections
         InitInp%Nodes(I)%ConnectionList = InitInp%InpJoints(I)%ConnectionList
         InitInp%Nodes(I)%JointIndx      = I
         InitInp%Nodes(I)%NodeType       = 1  ! 1 = end of a member, 2 = interior of a member, 3 = super member node
         InitInp%Nodes(I)%FillFSLoc      = 0  ! TODO: This should be MSL2SWL once this is implemented
         InitInp%Nodes(I)%FillFlag       = .FALSE.
         InitInp%Nodes(I)%FillDensity    = 0.0
         
         
         
      END DO
      
      
          ! Allocate memory for Members arrays
          
      InitInp%NElements = InitInp%NMembers  
      
      ALLOCATE ( InitInp%Elements(maxElements), STAT = ErrStat )
      IF ( ErrStat /= ErrID_None ) THEN
         ErrMsg  = ' Error allocating space for Elements array.'
         ErrStat = ErrID_Fatal
         RETURN
      END IF
          
      
      DO I = 1,InitInp%NMembers  
         
         InitInp%Elements(I)%Node1Indx = InitInp%InpMembers(I)%MJointID1Indx              ! Index of  the first node in the Morison_NodeType array
         InitInp%Elements(I)%Node2Indx = InitInp%InpMembers(I)%MJointID2Indx              ! Index of  the second node in the Morison_NodeType array
         node1Indx                     = InitInp%Elements(I)%Node1Indx
         node2Indx                     = InitInp%Elements(I)%Node2Indx
         prop1Indx = InitInp%InpMembers(I)%MPropSetID1Indx
         prop2Indx = InitInp%InpMembers(I)%MPropSetID2Indx
         
            ! Make sure that Node1 has the lower Z value, re-order if necessary
            ! We need to do this because the local element coordinate system is defined such that the first node is located with a smaller global Z value
            ! than the second node.
            ! The local element coordinate system requires that Z1 <= Z2, and if Z1=Z2 then X1 <= X2, and if Z1=Z2, X1=X2 then Y1<Y2
   
         InitInp%Elements(I)%InpMbrDist1         = 0.0
         InitInp%Elements(I)%InpMbrDist2         = 1.0
         doSwap = .FALSE.
                          
         IF ( EqualRealNos(InitInp%Nodes(node1Indx)%JointPos(3), InitInp%Nodes(node2Indx)%JointPos(3) ) ) THEN         ! Z1 = Z2          
            IF ( EqualRealNos(InitInp%Nodes(node1Indx)%JointPos(1), InitInp%Nodes(node2Indx)%JointPos(1) ) ) THEN      ! X1 = X2
               IF   ( InitInp%Nodes(node1Indx)%JointPos(2) > InitInp%Nodes(node2Indx)%JointPos(2) ) THEN
                  doSwap = .TRUE.  ! Y1 > Y2
               END IF
            ELSE IF ( InitInp%Nodes(node1Indx)%JointPos(1) > InitInp%Nodes(node2Indx)%JointPos(1) ) THEN
               doSwap = .TRUE.  ! X1 > X2
            END IF
         ELSE IF    ( InitInp%Nodes(node1Indx)%JointPos(3) > InitInp%Nodes(node2Indx)%JointPos(3) ) THEN
            doSwap = .TRUE.                                ! Z1 > Z2  
         END IF
         
         IF ( doSwap ) THEN
            
               ! Swap node indices to satisfy orientation rules for element nodes
            
            InitInp%Elements(I)%Node1Indx = InitInp%InpMembers(I)%MJointID2Indx              
            InitInp%Elements(I)%Node2Indx = InitInp%InpMembers(I)%MJointID1Indx  
            node1Indx                     = InitInp%Elements(I)%Node1Indx
            node2Indx                     = InitInp%Elements(I)%Node2Indx
            temp = prop1Indx
            prop1Indx = prop2Indx
            prop2Indx = temp
            InitInp%Elements(I)%InpMbrDist1         = 1.0
            InitInp%Elements(I)%InpMbrDist2         = 0.0
            
         END IF
         
         propSet = InitInp%MPropSets(prop1Indx)
         InitInp%Elements(I)%R1               = propSet%PropD / 2.0
         InitInp%Elements(I)%t1               = propSet%PropThck
         
         propSet = InitInp%MPropSets(prop2Indx)
         InitInp%Elements(I)%R2               = propSet%PropD / 2.0
         InitInp%Elements(I)%t2               = propSet%PropThck 
         
         InitInp%Elements(I)%NumSplits        = InitInp%InpMembers(I)%NumSplits
         InitInp%Elements(I)%Splits        = InitInp%InpMembers(I)%Splits
         !InitInp%Elements(I)%MGSplitState     = InitInp%InpMembers(I)%MGSplitState
         !InitInp%Elements(I)%WtrSplitState     = InitInp%InpMembers(I)%WtrSplitState
         InitInp%Elements(I)%MDivSize         = InitInp%InpMembers(I)%MDivSize
         InitInp%Elements(I)%MCoefMod         = InitInp%InpMembers(I)%MCoefMod
         InitInp%Elements(I)%MmbrCoefIDIndx   = InitInp%InpMembers(I)%MmbrCoefIDIndx
         InitInp%Elements(I)%MmbrFilledIDIndx = InitInp%InpMembers(I)%MmbrFilledIDIndx
      
         CALL GetDistance( InitInp%Nodes(node1Indx)%JointPos, InitInp%Nodes(node2Indx)%JointPos, d)
         
         InitInp%Elements(I)%InpMbrLen           = d
         InitInp%Elements(I)%InpMbrIndx          = I
         
            ! Direction cosines matrix which transforms a point in member coordinates to the global inertial system
         !CALL Morison_DirCosMtrx( node1%JointPos, node2%JointPos, InitInp%Elements(I)%R_LToG  )    
         
        
         InitInp%Elements(I)%PropWAMIT  =  InitInp%InpMembers(I)%PropWAMIT                  ! Flag specifying whether member is modelled in WAMIT [true = modelled in WAMIT, false = not modelled in WAMIT]
         
         
        
         
            ! Calculate the element-level direction cosine matrix and attach it to the entry in the elements array
            
         CALL Morison_DirCosMtrx( InitInp%Nodes(node1Indx)%JointPos, InitInp%Nodes(node2Indx)%JointPos, InitInp%Elements(I)%R_LToG )
        ! InitInp%Nodes(node1Indx)%R_LToG = InitInp%Elements(I)%R_LToG
        ! InitInp%Nodes(node2Indx)%R_LToG = InitInp%Elements(I)%R_LToG
      END DO
      
      
      
         ! Set the fill properties onto the elements
         
      CALL SetElementFillProps( InitInp%NFillGroups, InitInp%FilledGroups, InitInp%NElements, InitInp%Elements )
    
         ! Split elements
      CALL SplitElements(InitInp%NNodes, InitInp%Nodes, InitInp%NElements, InitInp%Elements, ErrStat, ErrMsg)
      
         ! Split element due to MSL2SWL location and seabed location
      !CALL SplitElementsForWtr(InitInp%MSL2SWL, -InitInp%WtrDpth, InitInp%NNodes, InitInp%Nodes, InitInp%NElements, InitInp%Elements, ErrStat, ErrMsg)
      
         ! Split elements if they cross the marine growth boundary. 
         
      !CALL SplitElementsForMG(InitInp%MGTop, InitInp%MGBottom, InitInp%NNodes, InitInp%Nodes, InitInp%NElements, InitInp%Elements, ErrStat, ErrMsg)
      
      
         ! Create any Super Members
      !CALL CreateSuperMembers( InitInp%NNodes, InitInp%Nodes, InitInp%NElements, InitInp%Elements, ErrStat, ErrMsg )
      
         ! Subdivide the members based on user-requested maximum division sizes (MDivSize)
         
      CALL SubdivideMembers( InitInp%NNodes, InitInp%Nodes, InitInp%NElements, InitInp%Elements, ErrStat, ErrMsg )  
      
    
         
         ! Set the element Cd and Ca coefs
         
      CALL SetElementCoefs( InitInp%SimplCd, InitInp%SimplCdMG, InitInp%SimplCa, InitInp%SimplCaMG, InitInp%CoefMembers, InitInp%NCoefDpth, InitInp%CoefDpths, InitInp%NNodes, InitInp%Nodes, InitInp%NElements, InitInp%Elements )   
      
      
         ! Set the heave coefs HvCd and HvCa
     CALL SetHeaveCoefs( InitInp%NJoints, InitInp%NHvCoefs, InitInp%HeaveCoefs, InitInp%NNodes, InitInp%Nodes, InitInp%NElements, InitInp%Elements )      
      
         ! Set the marine growth thickness and density information onto the nodes (this is not a per-element quantity, but a per-node quantity
         
      CALL SetNodeMG( InitInp%NMGDepths, InitInp%MGDepths, InitInp%NNodes, InitInp%Nodes )
      
      
         ! Create duplicate nodes at the ends of elements so that only one element is connected to any given end node
         
      CALL SplitMeshNodes( InitInp%NNodes, InitInp%Nodes, InitInp%NElements, InitInp%Elements, numSplitNodes, splitNodes, ErrStat, ErrMsg )
      
      IF (numSplitNodes > InitInp%NNodes ) THEN
         
         InitInp%NNodes = numSplitNodes
         !Reallocate the Nodes array
         DEALLOCATE ( InitInp%Nodes )
         ALLOCATE ( InitInp%Nodes(numSplitNodes), STAT = ErrStat )
         IF ( ErrStat /= ErrID_None ) THEN
            ErrMsg  = ' Error allocating space for Nodes array.'
            ErrStat = ErrID_Fatal
            RETURN
         END IF
         InitInp%Nodes = splitNodes
         DEALLOCATE ( splitNodes )
         
      END IF
      
      
         ! Now that the nodes are split, we can push the element properties down to the individual nodes without an issue
         
      CALL SetSplitNodeProperties( InitInp%NNodes, InitInp%Nodes, InitInp%NElements, InitInp%Elements, ErrStat, ErrMsg ) 
      
      
      
         
         ! 6) Store information necessary to compute the user-requested member outputs and joint outputs.  The requested output locations
         !    may be located in between two simulation nodes, so quantities will need to be interpolated. qOutput = q1*s + q2*(1-s), where 0<= s <= 1.
         
         ! NOTE: since we need to mantain the input geometry, the altered members are now part of the simulation mesh and 
         !       we will generate a mapping between the input and simulation meshes which is needed to generate user-requested outputs.
   
    
         
   ELSE  
      
      
         ! No Morison elements, so no processing is necessary, but set nodes and elements to 0.
         
     ! p%NMorisonNodes    = 0  
    !  p%NMorisonElements = 0
      
   END IF
   
END SUBROUTINE Morison_ProcessMorisonGeometry

!----------------------------------------------------------------------------------------------------------------------------------
SUBROUTINE Morison_Init( InitInp, u, p, x, xd, z, OtherState, y, Interval, InitOut, ErrStat, ErrMsg )
! This routine is called at the start of the simulation to perform initialization steps. 
! The parameters are set here and not changed during the simulation.
! The initial states and initial guess for the input are defined.
!..................................................................................................................................

      TYPE(Morison_InitInputType),       INTENT(IN   )  :: InitInp     ! Input data for initialization routine
      TYPE(Morison_InputType),           INTENT(  OUT)  :: u           ! An initial guess for the input; input mesh must be defined
      TYPE(Morison_ParameterType),       INTENT(  OUT)  :: p           ! Parameters      
      TYPE(Morison_ContinuousStateType), INTENT(  OUT)  :: x           ! Initial continuous states
      TYPE(Morison_DiscreteStateType),   INTENT(  OUT)  :: xd          ! Initial discrete states
      TYPE(Morison_ConstraintStateType), INTENT(  OUT)  :: z           ! Initial guess of the constraint states
      TYPE(Morison_OtherStateType),      INTENT(  OUT)  :: OtherState  ! Initial other/optimization states            
      TYPE(Morison_OutputType),          INTENT(  OUT)  :: y           ! Initial system outputs (outputs are not calculated; 
                                                                       !   only the output mesh is initialized)
      REAL(DbKi),                        INTENT(INOUT)  :: Interval    ! Coupling interval in seconds: the rate that 
                                                                       !   (1) Morison_UpdateStates() is called in loose coupling &
                                                                       !   (2) Morison_UpdateDiscState() is called in tight coupling.
                                                                       !   Input is the suggested time from the glue code; 
                                                                       !   Output is the actual coupling interval that will be used 
                                                                       !   by the glue code.
      TYPE(Morison_InitOutputType),      INTENT(  OUT)  :: InitOut     ! Output for initialization routine
      INTEGER(IntKi),                    INTENT(  OUT)  :: ErrStat     ! Error status of the operation
      CHARACTER(*),                      INTENT(  OUT)  :: ErrMsg      ! Error message if ErrStat /= ErrID_None

      
     ! TYPE(Morison_InitInputType)                       :: InitLocal   ! Local version of the input data for the geometry processing routine
      INTEGER, ALLOCATABLE                                          :: distribToNodeIndx(:)
      INTEGER, ALLOCATABLE                                          :: lumpedToNodeIndx(:)
      
         ! Initialize ErrStat
         
      ErrStat = ErrID_None         
      ErrMsg  = ""               
      
      
         ! Initialize the NWTC Subroutine Library
         
      CALL NWTC_Init(  )


     ! InitLocal = InitInp
      p%WtrDens    = InitInp%WtrDens
      p%NumOuts    = InitInp%NumOuts
      p%NMOutputs  = InitInp%NMOutputs                       ! Number of members to output [ >=0 and <10]
      p%OutSwtch   = InitInp%OutSwtch
      ALLOCATE ( p%MOutLst(p%NMOutputs), STAT = ErrStat )
      IF ( ErrStat /= ErrID_None ) THEN
         ErrMsg  = ' Error allocating space for MOutLst array.'
         ErrStat = ErrID_Fatal
         RETURN
      END IF
IF (ALLOCATED(InitInp%MOutLst) ) &
      p%MOutLst =    InitInp%MOutLst           ! Member output data
      
      p%NJOutputs = InitInp%NJOutputs                        ! Number of joints to output [ >=0 and <10]
      
      ALLOCATE ( p%JOutLst(p%NJOutputs), STAT = ErrStat )
      IF ( ErrStat /= ErrID_None ) THEN
         ErrMsg  = ' Error allocating space for JOutLst array.'
         ErrStat = ErrID_Fatal
         RETURN
      END IF
IF (ALLOCATED(InitInp%JOutLst) ) &
      p%JOutLst =    InitInp%JOutLst            ! Joint output data
      
     
      
      
       
      p%NNodes   = InitInp%NNodes
      
      ALLOCATE ( p%Nodes(p%NNodes), STAT = ErrStat )
      IF ( ErrStat /= ErrID_None ) THEN
         ErrMsg  = ' Error allocating space for Nodes array.'
         ErrStat = ErrID_Fatal
         RETURN
      END IF
      
      p%Nodes    = InitInp%Nodes
      
      
      p%NStepWave= InitInp%NStepWave
      
      ALLOCATE ( p%WaveVel0(0:p%NStepWave, p%NNodes, 3), STAT = ErrStat )
      IF ( ErrStat /= ErrID_None ) THEN
         ErrMsg  = ' Error allocating space for wave velocities array.'
         ErrStat = ErrID_Fatal
         RETURN
      END IF
      p%WaveVel0 = InitInp%WaveVel0
      
      ALLOCATE ( p%WaveAcc0(0:p%NStepWave, p%NNodes, 3), STAT = ErrStat )
      IF ( ErrStat /= ErrID_None ) THEN
         ErrMsg  = ' Error allocating space for wave accelerations array.'
         ErrStat = ErrID_Fatal
         RETURN
      END IF
      p%WaveAcc0 = InitInp%WaveAcc0
      
       ALLOCATE ( p%WaveDynP0(0:p%NStepWave, p%NNodes), STAT = ErrStat )
      IF ( ErrStat /= ErrID_None ) THEN
         ErrMsg  = ' Error allocating space for wave dynamic pressure array.'
         ErrStat = ErrID_Fatal
         RETURN
      END IF
      p%WaveDynP0 = InitInp%WaveDynP0
      
      
      ALLOCATE ( p%WaveTime(0:p%NStepWave), STAT = ErrStat )
      IF ( ErrStat /= ErrID_None ) THEN
         ErrMsg  = ' Error allocating space for wave time array.'
         ErrStat = ErrID_Fatal
         RETURN
      END IF     
      p%WaveTime     = InitInp%WaveTime
        
       
      p%NWaveElev    = InitInp%NWaveElev
      
         ! Copy Input Init data into parameters
      ALLOCATE ( p%WaveElev      (0:p%NStepWave, p%NWaveElev  ) , STAT=ErrStat )
      IF ( ErrStat /= ErrID_None )  THEN
         ErrMsg  = ' Error allocating memory for the WaveElev array.'
         ErrStat = ErrID_Fatal
         RETURN
      END IF    
      p%WaveElev     = InitInp%WaveElev
      
      
         ! Use the processed geometry information to create the distributed load mesh and associated marker parameters
         
         ! We are storing the parameters in the DistribMarkers data structure instead of trying to hold this information within the DistribMesh.  But these two data structures
         ! must always be in sync.  For example, the 5th element of the DistribMarkers array must correspond to the 5th node in the DistribMesh data structure.
       
      CALL CreateDistributedMesh( InitInp%WtrDens, InitInp%Gravity, InitInp%MSL2SWL, InitInp%WtrDpth, InitInp%NStepWave, InitInp%WaveAcc0, InitInp%WaveDynP0, &
                                  p%NNodes, p%Nodes, InitInp%NElements, InitInp%Elements, &
                                  p%NDistribMarkers, u%DistribMesh, y%DistribMesh, p%distribToNodeIndx, &
                                  p%D_F_I, p%D_F_B, p%D_F_DP, p%D_F_MG, p%D_F_BF, p%D_AM_M, p%D_AM_MG, p%D_AM_F, p%D_dragConst, &                 ! 
                                    ErrStat, ErrMsg )
     IF ( ErrStat > ErrID_None ) RETURN
     CALL CreateLumpedMesh( InitInp%WtrDens, InitInp%Gravity, InitInp%MSL2SWL, InitInp%WtrDpth, InitInp%NStepWave, InitInp%WaveDynP0, p%NNodes, p%Nodes, InitInp%NElements, InitInp%Elements, &
                                  p%NLumpedMarkers,  u%LumpedMesh, y%LumpedMesh, p%lumpedToNodeIndx,   p%L_An,     &
                                  p%L_F_B, p%L_F_DP, p%L_F_BF, p%L_AM_M, p%L_dragConst, &
                                  ErrStat, ErrMsg )
     IF ( ErrStat > ErrID_None ) RETURN
      !,  p%DistribMarkers,  p%Nodes, p%distribToNodeIndx
      
      
     ! CALL CreateSuperMesh( InitInp%NNodes, InitInp%Nodes, InitInp%NElements, InitInp%Elements, p%NSuperMarkers, p%SuperMarkers, InitOut%LumpedMesh, ErrStat, ErrMsg )
      
     
     
      
      
         ! Define parameters here:
       
     
      p%DT  = Interval


         ! Define initial system states here:

      x%DummyContState           = 0
      xd%DummyDiscState          = 0
      z%DummyConstrState         = 0
      OtherState%LastIndWave     = 1

   IF ( p%OutSwtch > 0 ) THEN
      ALLOCATE ( OtherState%D_F_D(3,y%DistribMesh%Nnodes), STAT = ErrStat )
      IF ( ErrStat /= ErrID_None ) THEN
         ErrMsg  = ' Error allocating space for D_F_D array.'
         ErrStat = ErrID_Fatal
         RETURN
      END IF
      ALLOCATE ( OtherState%D_F_I(3,y%DistribMesh%Nnodes), STAT = ErrStat )
      IF ( ErrStat /= ErrID_None ) THEN
         ErrMsg  = ' Error allocating space for D_F_I array.'
         ErrStat = ErrID_Fatal
         RETURN
      END IF
      ALLOCATE ( OtherState%D_F_DP(6,y%DistribMesh%Nnodes), STAT = ErrStat )
      IF ( ErrStat /= ErrID_None ) THEN
         ErrMsg  = ' Error allocating space for D_F_DP array.'
         ErrStat = ErrID_Fatal
         RETURN
      END IF
      ALLOCATE ( OtherState%D_F_AM(6,y%DistribMesh%Nnodes), STAT = ErrStat )
      IF ( ErrStat /= ErrID_None ) THEN
         ErrMsg  = ' Error allocating space for D_F_AM array.'
         ErrStat = ErrID_Fatal
         RETURN
      END IF
      ALLOCATE ( OtherState%D_F_AM_M(6,y%DistribMesh%Nnodes), STAT = ErrStat )
      IF ( ErrStat /= ErrID_None ) THEN
         ErrMsg  = ' Error allocating space for D_F_AM_M array.'
         ErrStat = ErrID_Fatal
         RETURN
      END IF
      ALLOCATE ( OtherState%D_F_AM_MG(6,y%DistribMesh%Nnodes), STAT = ErrStat )
      IF ( ErrStat /= ErrID_None ) THEN
         ErrMsg  = ' Error allocating space for D_F_AM_MG array.'
         ErrStat = ErrID_Fatal
         RETURN
      END IF
      ALLOCATE ( OtherState%D_F_AM_F(6,y%DistribMesh%Nnodes), STAT = ErrStat )
      IF ( ErrStat /= ErrID_None ) THEN
         ErrMsg  = ' Error allocating space for D_F_AM_F array.'
         ErrStat = ErrID_Fatal
         RETURN
      END IF
      ALLOCATE ( OtherState%D_FV(3,y%DistribMesh%Nnodes), STAT = ErrStat )
      IF ( ErrStat /= ErrID_None ) THEN
         ErrMsg  = ' Error allocating space for D_FV array.'
         ErrStat = ErrID_Fatal
         RETURN
      END IF
      ALLOCATE ( OtherState%D_FA(3,y%DistribMesh%Nnodes), STAT = ErrStat )
      IF ( ErrStat /= ErrID_None ) THEN
         ErrMsg  = ' Error allocating space for D_FA array.'
         ErrStat = ErrID_Fatal
         RETURN
      END IF
      ALLOCATE ( OtherState%D_FDynP(y%DistribMesh%Nnodes), STAT = ErrStat )
      IF ( ErrStat /= ErrID_None ) THEN
         ErrMsg  = ' Error allocating space for D_FDynP array.'
         ErrStat = ErrID_Fatal
         RETURN
      END IF
      
      ALLOCATE ( OtherState%L_F_D(3,y%LumpedMesh%Nnodes), STAT = ErrStat )
      IF ( ErrStat /= ErrID_None ) THEN
         ErrMsg  = ' Error allocating space for L_F_D array.'
         ErrStat = ErrID_Fatal
         RETURN
      END IF
      
      ALLOCATE ( OtherState%L_F_DP(6,y%LumpedMesh%Nnodes), STAT = ErrStat )
      IF ( ErrStat /= ErrID_None ) THEN
         ErrMsg  = ' Error allocating space for L_F_DP array.'
         ErrStat = ErrID_Fatal
         RETURN
      END IF
      ALLOCATE ( OtherState%L_FV(3,y%LumpedMesh%Nnodes), STAT = ErrStat )
      IF ( ErrStat /= ErrID_None ) THEN
         ErrMsg  = ' Error allocating space for L_FV array.'
         ErrStat = ErrID_Fatal
         RETURN
      END IF
      ALLOCATE ( OtherState%L_FA(3,y%LumpedMesh%Nnodes), STAT = ErrStat )
      IF ( ErrStat /= ErrID_None ) THEN
         ErrMsg  = ' Error allocating space for L_FA array.'
         ErrStat = ErrID_Fatal
         RETURN
      END IF
      ALLOCATE ( OtherState%L_FDynP(y%LumpedMesh%Nnodes), STAT = ErrStat )
      IF ( ErrStat /= ErrID_None ) THEN
         ErrMsg  = ' Error allocating space for L_FDynP array.'
         ErrStat = ErrID_Fatal
         RETURN
      END IF
      ALLOCATE ( OtherState%L_F_AM(6,y%LumpedMesh%Nnodes), STAT = ErrStat )
      IF ( ErrStat /= ErrID_None ) THEN
         ErrMsg  = ' Error allocating space for L_F_AM array.'
         ErrStat = ErrID_Fatal
         RETURN
      END IF
      
         ! Define initial guess for the system inputs here:

  !    u%DummyInput = 0


         ! Define system output initializations (set up mesh) here:
  
         
         ! Define initialization-routine output here:
         
         ! Initialize the outputs
         
      CALL MrsnOUT_Init( InitInp, y, p, InitOut, ErrStat, ErrMsg )
      IF ( ErrStat > ErrID_None ) RETURN
      
         ! Determine if we need to perform output file handling
      
      IF ( p%OutSwtch == 1 .OR. p%OutSwtch == 3 ) THEN  
         CALL MrsnOUT_OpenOutput( Morison_ProgDesc%Name, InitInp%OutRootName, p, InitOut, ErrStat, ErrMsg )
         IF ( ErrStat > ErrID_None ) RETURN
      END IF
      
   END IF  
   
   
      ! Write Summary information now that everything has been initialized.
      
   CALL WriteSummaryFile( InitInp%UnSum, InitInp%MSL2SWL, InitInp%NNodes, InitInp%Nodes, InitInp%NElements, InitInp%Elements, p%NumOuts, p%OutParam, p%NMOutputs, p%MOutLst, p%NJOutputs, p%JOutLst, u%LumpedMesh, y%LumpedMesh,u%DistribMesh, y%DistribMesh, p%L_F_B, p%L_F_BF, p%D_F_B, p%D_F_BF, p%D_F_MG, InitInp%Gravity, ErrStat, ErrMsg ) !p%NDistribMarkers, distribMarkers, p%NLumpedMarkers, lumpedMarkers,
   IF ( ErrStat > ErrID_None ) RETURN  
      
         ! If you want to choose your own rate instead of using what the glue code suggests, tell the glue code the rate at which
         !   this module must be called here:
         
       !Interval = p%DT                                               
   !Contains:
   !   SUBROUTINE CleanUpInitOnErr
   !   IF (ALLOCATED(sw(1)%array))  DEALLOCATE(sw(1)%array, STAT=aviFail)
   !   END SUBROUTINE

END SUBROUTINE Morison_Init


!----------------------------------------------------------------------------------------------------------------------------------
SUBROUTINE Morison_End( u, p, x, xd, z, OtherState, y, ErrStat, ErrMsg )
! This routine is called at the end of the simulation.
!..................................................................................................................................

      TYPE(Morison_InputType),           INTENT(INOUT)  :: u           ! System inputs
      TYPE(Morison_ParameterType),       INTENT(INOUT)  :: p           ! Parameters     
      TYPE(Morison_ContinuousStateType), INTENT(INOUT)  :: x           ! Continuous states
      TYPE(Morison_DiscreteStateType),   INTENT(INOUT)  :: xd          ! Discrete states
      TYPE(Morison_ConstraintStateType), INTENT(INOUT)  :: z           ! Constraint states
      TYPE(Morison_OtherStateType),      INTENT(INOUT)  :: OtherState  ! Other/optimization states            
      TYPE(Morison_OutputType),          INTENT(INOUT)  :: y           ! System outputs
      INTEGER(IntKi),                    INTENT(  OUT)  :: ErrStat     ! Error status of the operation
      CHARACTER(*),                      INTENT(  OUT)  :: ErrMsg      ! Error message if ErrStat /= ErrID_None



         ! Initialize ErrStat
         
      ErrStat = ErrID_None         
      ErrMsg  = ""               
      
      
         ! Place any last minute operations or calculations here:


         ! Close files here:     
                  
                  

         ! Destroy the input data:
         
      CALL Morison_DestroyInput( u, ErrStat, ErrMsg )


         ! Determine if we need to close the output file
         
      IF ( p%OutSwtch == 1 .OR. p%OutSwtch == 3 ) THEN   
         CALL MrsnOut_CloseOutput( p, ErrStat, ErrMsg )         
      END IF 
         
         ! Destroy the parameter data:
         
      
      CALL Morison_DestroyParam( p, ErrStat, ErrMsg )


         ! Destroy the state data:
         
      CALL Morison_DestroyContState(   x,           ErrStat, ErrMsg )
      CALL Morison_DestroyDiscState(   xd,          ErrStat, ErrMsg )
      CALL Morison_DestroyConstrState( z,           ErrStat, ErrMsg )
      CALL Morison_DestroyOtherState(  OtherState,  ErrStat, ErrMsg )
         

         ! Destroy the output data:
         
      CALL Morison_DestroyOutput( y, ErrStat, ErrMsg )


      

END SUBROUTINE Morison_End
!----------------------------------------------------------------------------------------------------------------------------------
SUBROUTINE Morison_UpdateStates( Time, u, p, x, xd, z, OtherState, ErrStat, ErrMsg )
! Loose coupling routine for solving for constraint states, integrating continuous states, and updating discrete states
! Constraint states are solved for input Time; Continuous and discrete states are updated for Time + Interval
!..................................................................................................................................
   
      REAL(DbKi),                         INTENT(IN   ) :: Time        ! Current simulation time in seconds
      TYPE(Morison_InputType),            INTENT(IN   ) :: u           ! Inputs at Time                    
      TYPE(Morison_ParameterType),        INTENT(IN   ) :: p           ! Parameters                              
      TYPE(Morison_ContinuousStateType),  INTENT(INOUT) :: x           ! Input: Continuous states at Time; 
                                                                       !   Output: Continuous states at Time + Interval
      TYPE(Morison_DiscreteStateType),    INTENT(INOUT) :: xd          ! Input: Discrete states at Time; 
                                                                       !   Output: Discrete states at Time  + Interval
      TYPE(Morison_ConstraintStateType),  INTENT(INOUT) :: z           ! Input: Initial guess of constraint states at Time;
                                                                       !   Output: Constraint states at Time
      TYPE(Morison_OtherStateType),       INTENT(INOUT) :: OtherState  ! Other/optimization states
      INTEGER(IntKi),                     INTENT(  OUT) :: ErrStat     ! Error status of the operation     
      CHARACTER(*),                       INTENT(  OUT) :: ErrMsg      ! Error message if ErrStat /= ErrID_None

         ! Local variables
         
      TYPE(Morison_ContinuousStateType)                 :: dxdt        ! Continuous state derivatives at Time
      TYPE(Morison_ConstraintStateType)                 :: z_Residual  ! Residual of the constraint state equations (Z)
         
      INTEGER(IntKi)                                    :: ErrStat2    ! Error status of the operation (occurs after initial error)
      CHARACTER(LEN(ErrMsg))                            :: ErrMsg2     ! Error message if ErrStat2 /= ErrID_None
                        
         ! Initialize ErrStat
         
      ErrStat = ErrID_None         
      ErrMsg  = ""               
      
           
      
         ! Solve for the constraint states (z) here:
                           
         ! Check if the z guess is correct and update z with a new guess.
         ! Iterate until the value is within a given tolerance. 
                                    
      CALL Morison_CalcConstrStateResidual( Time, u, p, x, xd, z, OtherState, z_Residual, ErrStat, ErrMsg )
      IF ( ErrStat >= AbortErrLev ) THEN      
         CALL Morison_DestroyConstrState( z_Residual, ErrStat2, ErrMsg2)
         ErrMsg = TRIM(ErrMsg)//' '//TRIM(ErrMsg2)
         RETURN      
      END IF
         
      ! DO WHILE ( z_Residual% > tolerance )
      !
      !  z = 
      !
      !  CALL Morison_CalcConstrStateResidual( Time, u, p, x, xd, z, OtherState, z_Residual, ErrStat, ErrMsg )
      !  IF ( ErrStat >= AbortErrLev ) THEN      
      !     CALL Morison_DestroyConstrState( z_Residual, ErrStat2, ErrMsg2)
      !     ErrMsg = TRIM(ErrMsg)//' '//TRIM(ErrMsg2)
      !     RETURN      
      !  END IF
      !           
      ! END DO         
      
      
         ! Destroy z_Residual because it is not necessary for the rest of the subroutine:
            
      CALL Morison_DestroyConstrState( z_Residual, ErrStat, ErrMsg)
      IF ( ErrStat >= AbortErrLev ) RETURN      
         
         
         
         ! Get first time derivatives of continuous states (dxdt):
      
      CALL Morison_CalcContStateDeriv( Time, u, p, x, xd, z, OtherState, dxdt, ErrStat, ErrMsg )
      IF ( ErrStat >= AbortErrLev ) THEN      
         CALL Morison_DestroyContState( dxdt, ErrStat2, ErrMsg2)
         ErrMsg = TRIM(ErrMsg)//' '//TRIM(ErrMsg2)
         RETURN
      END IF
               
               
         ! Update discrete states:
         !   Note that xd [discrete state] is changed in Morison_UpdateDiscState(), so Morison_CalcOutput(),  
         !   Morison_CalcContStateDeriv(), and Morison_CalcConstrStates() must be called first (see above).
      
      CALL Morison_UpdateDiscState(Time, u, p, x, xd, z, OtherState, ErrStat, ErrMsg )   
      IF ( ErrStat >= AbortErrLev ) THEN      
         CALL Morison_DestroyContState( dxdt, ErrStat2, ErrMsg2)
         ErrMsg = TRIM(ErrMsg)//' '//TRIM(ErrMsg2)
         RETURN      
      END IF
         
         
         ! Integrate (update) continuous states (x) here:
         
      !x = function of dxdt and x


         ! Destroy dxdt because it is not necessary for the rest of the subroutine
            
      CALL Morison_DestroyContState( dxdt, ErrStat, ErrMsg)
      IF ( ErrStat >= AbortErrLev ) RETURN      
     
   
      
END SUBROUTINE Morison_UpdateStates
!----------------------------------------------------------------------------------------------------------------------------------
SUBROUTINE Morison_CalcOutput( Time, u, p, x, xd, z, OtherState, y, ErrStat, ErrMsg )   
! Routine for computing outputs, used in both loose and tight coupling.
!..................................................................................................................................
   
      REAL(DbKi),                        INTENT(IN   )  :: Time        ! Current simulation time in seconds
      TYPE(Morison_InputType),           INTENT(IN   )  :: u           ! Inputs at Time
      TYPE(Morison_ParameterType),       INTENT(IN   )  :: p           ! Parameters
      TYPE(Morison_ContinuousStateType), INTENT(IN   )  :: x           ! Continuous states at Time
      TYPE(Morison_DiscreteStateType),   INTENT(IN   )  :: xd          ! Discrete states at Time
      TYPE(Morison_ConstraintStateType), INTENT(IN   )  :: z           ! Constraint states at Time
      TYPE(Morison_OtherStateType),      INTENT(INOUT)  :: OtherState  ! Other/optimization states
      TYPE(Morison_OutputType),          INTENT(INOUT)  :: y           ! Outputs computed at Time (Input only so that mesh con-
                                                                       !   nectivity information does not have to be recalculated)
      INTEGER(IntKi),                    INTENT(  OUT)  :: ErrStat     ! Error status of the operation
      CHARACTER(*),                      INTENT(  OUT)  :: ErrMsg      ! Error message if ErrStat /= ErrID_None

      REAL(ReKi)                                        :: WaveElev (p%NWaveElev)                  ! Instantaneous elevation of incident waves at each of the NWaveElev points where the incident wave elevations can be output (meters)
      REAL(ReKi)                                        :: F_D(6), F_DP(6), F_I(6), kvec(3), v(3), m(3), vf(3), vrel(3), vmag
      INTEGER                                           :: I, J, K, nodeIndx
      REAL(ReKi)                                        :: AllOuts(MaxOutputs)  ! TODO: think about adding to OtherState
      REAL(ReKi)                                        :: qdotdot(6)     ! The structural acceleration of a mesh node
      REAL(ReKi)                                        :: dragFactor     ! The lumped drag factor
      REAL(ReKi)                                        :: AnProd         ! Dot product of the directional area of the joint
      
      
         ! Initialize ErrStat
         
      ErrStat = ErrID_None         
      ErrMsg  = ""               
      
      
         ! Compute outputs here:
      
      ! We need to attach the distributed drag force (D_F_D), distributed inertial force (D_F_I), and distributed dynamic pressure force (D_F_DP) to the OtherState type so that we don't need to
      ! allocate their data storage at each time step!  If we could make them static local variables (like in C) then we could avoid adding them to the OtherState datatype.  
      ! The same is true for the lumped drag (L_F_D) and the lumped dynamic pressure (L_F_DP)
         
      DO J = 1, y%DistribMesh%Nnodes
         
            ! Obtain the node index because WaveVel0, WaveAcc0, and WaveDynP0 are defined in the node indexing scheme, not the markers
         nodeIndx = p%distribToNodeIndx(J)
              
         
         ! Determine the dynamic pressure at the marker
         OtherState%D_FDynP(J) = InterpWrappedStpReal ( REAL(Time, ReKi), p%WaveTime(:), p%WaveDynP0(:,nodeIndx), &
                                    OtherState%LastIndWave, p%NStepWave + 1 )
         
            
         DO I=1,3
               ! Determine the fluid acceleration and velocity at the marker
            OtherState%D_FA(I,J) = InterpWrappedStpReal ( REAL(Time, ReKi), p%WaveTime(:), p%WaveAcc0(:,nodeIndx,I), &
                                    OtherState%LastIndWave, p%NStepWave + 1       )
            OtherState%D_FV(I,J) = InterpWrappedStpReal ( REAL(Time, ReKi), p%WaveTime(:), p%WaveVel0(:,nodeIndx,I), &
                                    OtherState%LastIndWave, p%NStepWave + 1       )
            vrel(I) =  OtherState%D_FV(I,J) - u%DistribMesh%TranslationVel(I,J)
         END DO
         
            ! (k x vrel x k)
         kvec =  p%Nodes(p%distribToNodeIndx(J))%R_LToG(:,3)
         m =  Cross_Product( kvec, vrel )
         v =  Cross_Product( m, kvec ) 
         v = Dot_Product(kvec,kvec)*vrel - Dot_Product(kvec,vrel)*kvec
         !  TODO: Check the following, HD v1 only had x and y in the sum of squares.  GJH 7/9/13
         vmag = sqrt( v(1)*v(1) + v(2)*v(2)  )
         
         
            ! Distributed added mass loads
            
         qdotdot              = reshape((/u%DistribMesh%TranslationAcc(:,J),u%DistribMesh%RotationAcc(:,J)/),(/6/))   
         OtherState%D_F_AM_MG(:,J) = -matmul( p%D_AM_MG(:,:,J), qdotdot )
         OtherState%D_F_AM_M(:,J)  = -matmul( p%D_AM_M(:,:,J) , qdotdot )
         OtherState%D_F_AM_F(:,J)  = -matmul( p%D_AM_F(:,:,J) , qdotdot )
         OtherState%D_F_AM(:,J)    = OtherState%D_F_AM_M(:,J) + OtherState%D_F_AM_MG(:,J) + OtherState%D_F_AM_F(:,J)    ! vector-based addition
         
         DO I=1,6
            
            
            OtherState%D_F_DP(I,J)   = InterpWrappedStpReal ( REAL(Time, ReKi), p%WaveTime(:), p%D_F_DP(:,I,J), &
                                    OtherState%LastIndWave, p%NStepWave + 1       )
            IF (I < 4 ) THEN
               OtherState%D_F_I(I,J) = InterpWrappedStpReal ( REAL(Time, ReKi), p%WaveTime(:), p%D_F_I(:,I,J), &
                                    OtherState%LastIndWave, p%NStepWave + 1       )
               ! TODO: Verify the following 9/29/13 GJH
               OtherState%D_F_D(I,J) = vmag*v(I) * p%D_dragConst(J)
               
               !y%DistribMesh%Force(I,J) = OtherState%D_F_D(I,J)  + OtherState%D_F_I(I,J) + p%D_F_B(I,J) + OtherState%D_F_DP(I,J) + p%D_F_MG(I,J) + p%D_F_BF(I,J)
               y%DistribMesh%Force(I,J) = OtherState%D_F_AM(I,J) + OtherState%D_F_D(I,J)  + OtherState%D_F_I(I,J) + p%D_F_B(I,J) + OtherState%D_F_DP(I,J) + p%D_F_MG(I,J) + p%D_F_BF(I,J)
            
            ELSE
               
               !y%DistribMesh%Moment(I-3,J) =   p%D_F_B(I,J) + p%D_F_BF(I,J)
                y%DistribMesh%Moment(I-3,J) =   OtherState%D_F_AM(I,J) + p%D_F_B(I,J) + p%D_F_BF(I,J)
               
            END IF
           
            
         END DO  ! DO I
         
         
         
      ENDDO
         
      DO J = 1, y%LumpedMesh%Nnodes
         
            ! Obtain the node index because WaveVel0, WaveAcc0, and WaveDynP0 are defined in the node indexing scheme, not the markers
         nodeIndx = p%lumpedToNodeIndx(J)
         
            ! Determine the dynamic pressure at the marker
         OtherState%L_FDynP(J) = InterpWrappedStpReal ( REAL(Time, ReKi), p%WaveTime(:), p%WaveDynP0(:,nodeIndx), &
                                    OtherState%LastIndWave, p%NStepWave + 1       )
         
         
         DO I=1,3
               ! Determine the fluid acceleration and velocity at the marker
            OtherState%L_FA(I,J) = InterpWrappedStpReal ( REAL(Time, ReKi), p%WaveTime(:), p%WaveAcc0(:,nodeIndx,I), &
                                    OtherState%LastIndWave, p%NStepWave + 1       )
               
            OtherState%L_FV(I,J) = InterpWrappedStpReal ( REAL(Time, ReKi), p%WaveTime(:), p%WaveVel0(:,nodeIndx,I), &
                                    OtherState%LastIndWave, p%NStepWave + 1       )
            vrel(I) =  OtherState%L_FV(I,J) - u%LumpedMesh%TranslationVel(I,J)
         END DO
         
         
        
            ! Compute the dot product of the relative velocity vector with the directional Area of the Joint
         vmag =  vrel(1)*p%L_An(1,J) + vrel(2)*p%L_An(2,J) + vrel(3)*p%L_An(3,J)
         AnProd = p%L_An(1,J)**2 + p%L_An(2,J)**2 + p%L_An(3,J)**2
         IF (EqualRealNos(AnProd, 0.0_ReKi)) THEN
            dragFactor = 0.0
         ELSE
            dragFactor = p%Nodes(nodeIndx)%HvCd*p%WtrDens*abs(vmag)*vmag / ( 4.0_ReKi * AnProd )
         END IF
         
         !  v = Dot_Product(kvec,kvec)*vrel - Dot_Product(kvec,vrel)*kvec
         !  TODO: Check the following, HD v1 only had x and y in the sum of squares.  GJH 7/9/13
         !vmag = sqrt( v(1)*v(1) + v(2)*v(2) + v(3)*v(3) )
         
         
            ! Lumped added mass loads
         qdotdot                 = reshape((/u%LumpedMesh%TranslationAcc(:,J),u%LumpedMesh%RotationAcc(:,J)/),(/6/))   
         OtherState%L_F_AM(:,J)  = -matmul( p%L_AM_M(:,:,J) , qdotdot )
         
         
         DO I=1,6
            
            OtherState%L_F_DP(I,J) = InterpWrappedStpReal ( REAL(Time, ReKi), p%WaveTime(:), p%L_F_DP(:,I,J), &
                                    OtherState%LastIndWave, p%NStepWave + 1       )
            
            IF (I < 4 ) THEN
   
               OtherState%L_F_D(I,J) =  p%L_An(I,J)*dragFactor !vmag*v(I) * p%L_dragConst(J)   ! TODO: Verify newly added heave drag GJH 11/07/13
               
               !y%LumpedMesh%Force(I,J) = OtherState%L_F_D(I,J) +  p%L_F_B(I,J) + OtherState%L_F_DP(I,J) +  p%L_F_BF(I,J)
               y%LumpedMesh%Force(I,J) = OtherState%L_F_AM(I,J) + OtherState%L_F_D(I,J) +  p%L_F_B(I,J) + OtherState%L_F_DP(I,J) +  p%L_F_BF(I,J)
            
            ELSE
               !y%LumpedMesh%Moment(I-3,J) =  p%L_F_B(I,J) +   p%L_F_BF(I,J)
               y%LumpedMesh%Moment(I-3,J) =   OtherState%L_F_AM(I,J) + p%L_F_B(I,J) +   p%L_F_BF(I,J)
            END IF
            
            
         END DO      
      ENDDO
      
      
         ! OutSwtch determines whether or not to actually output results via the WriteOutput array
         ! 1 = Morison will generate an output file of its own.  2 = the caller will handle the outputs, but
         ! Morison needs to provide them.  3 = Both 1 and 2, 0 = No one needs the Morison outputs provided
         ! via the WriteOutput array.
         
      IF ( p%OutSwtch > 0 ) THEN
         
            ! Compute the wave elevations at the requested output locations for this time, this is only needed if we are generating outputs
         DO I=1,p%NWaveElev   
            WaveElev(I) = InterpWrappedStpReal ( REAL(Time, ReKi), p%WaveTime(:), p%WaveElev(:,I), &
                                    OtherState%LastIndWave, p%NStepWave + 1       )
         END DO
         
            ! Map calculated results into the AllOuts Array
         CALL MrsnOut_MapOutputs(Time, y, p, OtherState, p%NWaveElev, WaveElev, AllOuts, ErrStat, ErrMsg)
               
      
            ! Put the output data in the WriteOutput array
   
         DO I = 1,p%NumOuts

            y%WriteOutput(I) = p%OutParam(I)%SignM * AllOuts( p%OutParam(I)%Indx )
      
         END DO
         
         
            ! Generate output into the output file
            
         IF ( p%OutSwtch == 1 .OR. p%OutSwtch == 3 ) THEN
            CALL MrsnOut_WriteOutputs( p%UnOutFile, Time, y, p, ErrStat, ErrMsg )         
         END IF
      END IF
      
   
END SUBROUTINE Morison_CalcOutput
!----------------------------------------------------------------------------------------------------------------------------------
SUBROUTINE Morison_CalcContStateDeriv( Time, u, p, x, xd, z, OtherState, dxdt, ErrStat, ErrMsg )  
! Tight coupling routine for computing derivatives of continuous states
!..................................................................................................................................
   
      REAL(DbKi),                        INTENT(IN   )  :: Time        ! Current simulation time in seconds
      TYPE(Morison_InputType),           INTENT(IN   )  :: u           ! Inputs at Time                    
      TYPE(Morison_ParameterType),       INTENT(IN   )  :: p           ! Parameters                             
      TYPE(Morison_ContinuousStateType), INTENT(IN   )  :: x           ! Continuous states at Time
      TYPE(Morison_DiscreteStateType),   INTENT(IN   )  :: xd          ! Discrete states at Time
      TYPE(Morison_ConstraintStateType), INTENT(IN   )  :: z           ! Constraint states at Time
      TYPE(Morison_OtherStateType),      INTENT(INOUT)  :: OtherState  ! Other/optimization states                    
      TYPE(Morison_ContinuousStateType), INTENT(  OUT)  :: dxdt        ! Continuous state derivatives at Time
      INTEGER(IntKi),                    INTENT(  OUT)  :: ErrStat     ! Error status of the operation     
      CHARACTER(*),                      INTENT(  OUT)  :: ErrMsg      ! Error message if ErrStat /= ErrID_None

               
         ! Initialize ErrStat
         
      ErrStat = ErrID_None         
      ErrMsg  = ""               
      
      
         ! Compute the first time derivatives of the continuous states here:
      
      dxdt%DummyContState = 0
         

END SUBROUTINE Morison_CalcContStateDeriv
!----------------------------------------------------------------------------------------------------------------------------------
SUBROUTINE Morison_UpdateDiscState( Time, u, p, x, xd, z, OtherState, ErrStat, ErrMsg )   
! Tight coupling routine for updating discrete states
!..................................................................................................................................
   
      REAL(DbKi),                        INTENT(IN   )  :: Time        ! Current simulation time in seconds   
      TYPE(Morison_InputType),           INTENT(IN   )  :: u           ! Inputs at Time                       
      TYPE(Morison_ParameterType),       INTENT(IN   )  :: p           ! Parameters                                 
      TYPE(Morison_ContinuousStateType), INTENT(IN   )  :: x           ! Continuous states at Time
      TYPE(Morison_DiscreteStateType),   INTENT(INOUT)  :: xd          ! Input: Discrete states at Time; 
                                                                       !   Output: Discrete states at Time + Interval
      TYPE(Morison_ConstraintStateType), INTENT(IN   )  :: z           ! Constraint states at Time
      TYPE(Morison_OtherStateType),      INTENT(INOUT)  :: OtherState  ! Other/optimization states           
      INTEGER(IntKi),                    INTENT(  OUT)  :: ErrStat     ! Error status of the operation
      CHARACTER(*),                      INTENT(  OUT)  :: ErrMsg      ! Error message if ErrStat /= ErrID_None

               
         ! Initialize ErrStat
         
      ErrStat = ErrID_None         
      ErrMsg  = ""               
      
      
         ! Update discrete states here:
      
      ! StateData%DiscState = 

END SUBROUTINE Morison_UpdateDiscState
!----------------------------------------------------------------------------------------------------------------------------------
SUBROUTINE Morison_CalcConstrStateResidual( Time, u, p, x, xd, z, OtherState, z_residual, ErrStat, ErrMsg )   
! Tight coupling routine for solving for the residual of the constraint state equations
!..................................................................................................................................
   
      REAL(DbKi),                        INTENT(IN   )  :: Time        ! Current simulation time in seconds   
      TYPE(Morison_InputType),           INTENT(IN   )  :: u           ! Inputs at Time                       
      TYPE(Morison_ParameterType),       INTENT(IN   )  :: p           ! Parameters                           
      TYPE(Morison_ContinuousStateType), INTENT(IN   )  :: x           ! Continuous states at Time
      TYPE(Morison_DiscreteStateType),   INTENT(IN   )  :: xd          ! Discrete states at Time
      TYPE(Morison_ConstraintStateType), INTENT(IN   )  :: z           ! Constraint states at Time (possibly a guess)
      TYPE(Morison_OtherStateType),      INTENT(INOUT)  :: OtherState  ! Other/optimization states                    
      TYPE(Morison_ConstraintStateType), INTENT(  OUT)  :: z_residual  ! Residual of the constraint state equations using  
                                                                       !     the input values described above      
      INTEGER(IntKi),                    INTENT(  OUT)  :: ErrStat     ! Error status of the operation
      CHARACTER(*),                      INTENT(  OUT)  :: ErrMsg      ! Error message if ErrStat /= ErrID_None

               
         ! Initialize ErrStat
         
      ErrStat = ErrID_None         
      ErrMsg  = ""               
      
      
         ! Solve for the constraint states here:
      
      z_residual%DummyConstrState = 0

END SUBROUTINE Morison_CalcConstrStateResidual
!----------------------------------------------------------------------------------------------------------------------------------
!SUBROUTINE Morison_JacobianPInput( Time, u, p, x, xd, z, OtherState, dYdu, dXdu, dXddu, dZdu, ErrStat, ErrMsg )   
!! Routine to compute the Jacobians of the output (Y), continuous- (X), discrete- (Xd), and constraint-state (Z) equations 
!! with respect to the inputs (u). The partial derivatives dY/du, dX/du, dXd/du, and DZ/du are returned.
!!..................................................................................................................................
!   
!      REAL(DbKi),                                INTENT(IN   )           :: Time       ! Current simulation time in seconds   
!      TYPE(Morison_InputType),                   INTENT(IN   )           :: u          ! Inputs at Time                       
!      TYPE(Morison_ParameterType),               INTENT(IN   )           :: p          ! Parameters                           
!      TYPE(Morison_ContinuousStateType),         INTENT(IN   )           :: x          ! Continuous states at Time
!      TYPE(Morison_DiscreteStateType),           INTENT(IN   )           :: xd         ! Discrete states at Time
!      TYPE(Morison_ConstraintStateType),         INTENT(IN   )           :: z          ! Constraint states at Time
!      TYPE(Morison_OtherStateType),              INTENT(INOUT)           :: OtherState ! Other/optimization states                    
!      TYPE(Morison_PartialOutputPInputType),     INTENT(  OUT), OPTIONAL :: dYdu       ! Partial derivatives of output equations
!                                                                                       !   (Y) with respect to the inputs (u)
!      TYPE(Morison_PartialContStatePInputType),  INTENT(  OUT), OPTIONAL :: dXdu       ! Partial derivatives of continuous state
!                                                                                       !   equations (X) with respect to inputs (u)
!      TYPE(Morison_PartialDiscStatePInputType),  INTENT(  OUT), OPTIONAL :: dXddu      ! Partial derivatives of discrete state 
!                                                                                       !   equations (Xd) with respect to inputs (u)
!      TYPE(Morison_PartialConstrStatePInputType),INTENT(  OUT), OPTIONAL :: dZdu       ! Partial derivatives of constraint state 
!                                                                                       !   equations (Z) with respect to inputs (u)
!      INTEGER(IntKi),                            INTENT(  OUT)           :: ErrStat    ! Error status of the operation
!      CHARACTER(*),                              INTENT(  OUT)           :: ErrMsg     ! Error message if ErrStat /= ErrID_None
!
!               
!         ! Initialize ErrStat
!         
!      ErrStat = ErrID_None         
!      ErrMsg  = ""               
!      
!      
!      IF ( PRESENT( dYdu ) ) THEN
!      
!         ! Calculate the partial derivative of the output equations (Y) with respect to the inputs (u) here:
!
!!         dYdu%DummyOutput%DummyInput = 0
!
!      END IF
!      
!      IF ( PRESENT( dXdu ) ) THEN
!      
!         ! Calculate the partial derivative of the continuous state equations (X) with respect to the inputs (u) here:
!      
!   !      dXdu%DummyContState%DummyInput = 0
!
!      END IF
!      
!      IF ( PRESENT( dXddu ) ) THEN
!
!         ! Calculate the partial derivative of the discrete state equations (Xd) with respect to the inputs (u) here:
!
!  !       dXddu%DummyDiscState%DummyInput = 0
!
!      END IF
!      
!      IF ( PRESENT( dZdu ) ) THEN
!
!         ! Calculate the partial derivative of the constraint state equations (Z) with respect to the inputs (u) here:
!      
! !        dZdu%DummyConstrState%DummyInput = 0
!
!      END IF
!
!
!END SUBROUTINE Morison_JacobianPInput
!!----------------------------------------------------------------------------------------------------------------------------------
!SUBROUTINE Morison_JacobianPContState( Time, u, p, x, xd, z, OtherState, dYdx, dXdx, dXddx, dZdx, ErrStat, ErrMsg )   
!! Routine to compute the Jacobians of the output (Y), continuous- (X), discrete- (Xd), and constraint-state (Z) equations
!! with respect to the continuous states (x). The partial derivatives dY/dx, dX/dx, dXd/dx, and DZ/dx are returned.
!!..................................................................................................................................
!   
!      REAL(DbKi),                                    INTENT(IN   )           :: Time       ! Current simulation time in seconds   
!      TYPE(Morison_InputType),                       INTENT(IN   )           :: u          ! Inputs at Time                       
!      TYPE(Morison_ParameterType),                   INTENT(IN   )           :: p          ! Parameters                           
!      TYPE(Morison_ContinuousStateType),             INTENT(IN   )           :: x          ! Continuous states at Time
!      TYPE(Morison_DiscreteStateType),               INTENT(IN   )           :: xd         ! Discrete states at Time
!      TYPE(Morison_ConstraintStateType),             INTENT(IN   )           :: z          ! Constraint states at Time
!      TYPE(Morison_OtherStateType),                  INTENT(INOUT)           :: OtherState ! Other/optimization states                    
!      TYPE(Morison_PartialOutputPContStateType),     INTENT(  OUT), OPTIONAL :: dYdx       ! Partial derivatives of output equations
!                                                                                           !   (Y) with respect to the continuous 
!                                                                                           !   states (x)
!      TYPE(Morison_PartialContStatePContStateType),  INTENT(  OUT), OPTIONAL :: dXdx       ! Partial derivatives of continuous state
!                                                                                           !   equations (X) with respect to 
!                                                                                           !   the continuous states (x)
!      TYPE(Morison_PartialDiscStatePContStateType),  INTENT(  OUT), OPTIONAL :: dXddx      ! Partial derivatives of discrete state 
!                                                                                           !   equations (Xd) with respect to 
!                                                                                           !   the continuous states (x)
!      TYPE(Morison_PartialConstrStatePContStateType),INTENT(  OUT), OPTIONAL :: dZdx       ! Partial derivatives of constraint state
!                                                                                           !   equations (Z) with respect to 
!                                                                                           !   the continuous states (x)
!      INTEGER(IntKi),                                INTENT(  OUT)           :: ErrStat    ! Error status of the operation
!      CHARACTER(*),                                  INTENT(  OUT)           :: ErrMsg     ! Error message if ErrStat /= ErrID_None
!
!               
!         ! Initialize ErrStat
!         
!      ErrStat = ErrID_None         
!      ErrMsg  = ""               
!      
!      
!     
!      IF ( PRESENT( dYdx ) ) THEN
!
!         ! Calculate the partial derivative of the output equations (Y) with respect to the continuous states (x) here:
!
!         dYdx%DummyOutput%DummyContState = 0
!
!      END IF
!      
!      IF ( PRESENT( dXdx ) ) THEN
!      
!         ! Calculate the partial derivative of the continuous state equations (X) with respect to the continuous states (x) here:
!      
!         dXdx%DummyContState%DummyContState = 0
!
!      END IF
!      
!      IF ( PRESENT( dXddx ) ) THEN
!
!         ! Calculate the partial derivative of the discrete state equations (Xd) with respect to the continuous states (x) here:
!
!         dXddx%DummyDiscState%DummyContState = 0
!         
!      END IF
!      
!      IF ( PRESENT( dZdx ) ) THEN
!
!
!         ! Calculate the partial derivative of the constraint state equations (Z) with respect to the continuous states (x) here:
!      
!         dZdx%DummyConstrState%DummyContState = 0
!
!      END IF
!      
!
!   END SUBROUTINE Morison_JacobianPContState
!!----------------------------------------------------------------------------------------------------------------------------------
!SUBROUTINE Morison_JacobianPDiscState( Time, u, p, x, xd, z, OtherState, dYdxd, dXdxd, dXddxd, dZdxd, ErrStat, ErrMsg )   
!! Routine to compute the Jacobians of the output (Y), continuous- (X), discrete- (Xd), and constraint-state (Z) equations
!! with respect to the discrete states (xd). The partial derivatives dY/dxd, dX/dxd, dXd/dxd, and DZ/dxd are returned.
!!..................................................................................................................................
!
!      REAL(DbKi),                                    INTENT(IN   )           :: Time       ! Current simulation time in seconds   
!      TYPE(Morison_InputType),                       INTENT(IN   )           :: u          ! Inputs at Time                       
!      TYPE(Morison_ParameterType),                   INTENT(IN   )           :: p          ! Parameters                           
!      TYPE(Morison_ContinuousStateType),             INTENT(IN   )           :: x          ! Continuous states at Time
!      TYPE(Morison_DiscreteStateType),               INTENT(IN   )           :: xd         ! Discrete states at Time
!      TYPE(Morison_ConstraintStateType),             INTENT(IN   )           :: z          ! Constraint states at Time
!      TYPE(Morison_OtherStateType),                  INTENT(INOUT)           :: OtherState ! Other/optimization states                    
!      TYPE(Morison_PartialOutputPDiscStateType),     INTENT(  OUT), OPTIONAL :: dYdxd      ! Partial derivatives of output equations
!                                                                                           !  (Y) with respect to the discrete 
!                                                                                           !  states (xd)
!      TYPE(Morison_PartialContStatePDiscStateType),  INTENT(  OUT), OPTIONAL :: dXdxd      ! Partial derivatives of continuous state
!                                                                                           !   equations (X) with respect to the 
!                                                                                           !   discrete states (xd)
!      TYPE(Morison_PartialDiscStatePDiscStateType),  INTENT(  OUT), OPTIONAL :: dXddxd     ! Partial derivatives of discrete state 
!                                                                                           !   equations (Xd) with respect to the
!                                                                                           !   discrete states (xd)
!      TYPE(Morison_PartialConstrStatePDiscStateType),INTENT(  OUT), OPTIONAL :: dZdxd      ! Partial derivatives of constraint state
!                                                                                           !   equations (Z) with respect to the 
!                                                                                           !   discrete states (xd)
!      INTEGER(IntKi),                                INTENT(  OUT)           :: ErrStat    ! Error status of the operation
!      CHARACTER(*),                                  INTENT(  OUT)           :: ErrMsg     ! Error message if ErrStat /= ErrID_None
!
!               
!         ! Initialize ErrStat
!         
!      ErrStat = ErrID_None         
!      ErrMsg  = ""               
!      
!      
!      IF ( PRESENT( dYdxd ) ) THEN
!      
!         ! Calculate the partial derivative of the output equations (Y) with respect to the discrete states (xd) here:
!
!         dYdxd%DummyOutput%DummyDiscState = 0
!
!      END IF
!      
!      IF ( PRESENT( dXdxd ) ) THEN
!
!         ! Calculate the partial derivative of the continuous state equations (X) with respect to the discrete states (xd) here:
!      
!         dXdxd%DummyContState%DummyDiscState = 0
!
!      END IF
!      
!      IF ( PRESENT( dXddxd ) ) THEN
!
!         ! Calculate the partial derivative of the discrete state equations (Xd) with respect to the discrete states (xd) here:
!
!         dXddxd%DummyDiscState%DummyDiscState = 0
!
!      END IF
!      
!      IF ( PRESENT( dZdxd ) ) THEN
!
!         ! Calculate the partial derivative of the constraint state equations (Z) with respect to the discrete states (xd) here:
!      
!         dZdxd%DummyConstrState%DummyDiscState = 0
!
!      END IF
!      
!
!
!END SUBROUTINE Morison_JacobianPDiscState
!!----------------------------------------------------------------------------------------------------------------------------------    
!SUBROUTINE Morison_JacobianPConstrState( Time, u, p, x, xd, z, OtherState, dYdz, dXdz, dXddz, dZdz, ErrStat, ErrMsg )   
!! Routine to compute the Jacobians of the output (Y), continuous- (X), discrete- (Xd), and constraint-state (Z) equations
!! with respect to the constraint states (z). The partial derivatives dY/dz, dX/dz, dXd/dz, and DZ/dz are returned.
!!..................................................................................................................................
!   
!      REAL(DbKi),                                      INTENT(IN   )           :: Time       ! Current simulation time in seconds   
!      TYPE(Morison_InputType),                         INTENT(IN   )           :: u          ! Inputs at Time                       
!      TYPE(Morison_ParameterType),                     INTENT(IN   )           :: p          ! Parameters                           
!      TYPE(Morison_ContinuousStateType),               INTENT(IN   )           :: x          ! Continuous states at Time
!      TYPE(Morison_DiscreteStateType),                 INTENT(IN   )           :: xd         ! Discrete states at Time
!      TYPE(Morison_ConstraintStateType),               INTENT(IN   )           :: z          ! Constraint states at Time
!      TYPE(Morison_OtherStateType),                    INTENT(INOUT)           :: OtherState ! Other/optimization states                    
!      TYPE(Morison_PartialOutputPConstrStateType),     INTENT(  OUT), OPTIONAL :: dYdz       ! Partial derivatives of output 
!                                                                                             !  equations (Y) with respect to the 
!                                                                                             !  constraint states (z)
!      TYPE(Morison_PartialContStatePConstrStateType),  INTENT(  OUT), OPTIONAL :: dXdz       ! Partial derivatives of continuous
!                                                                                             !  state equations (X) with respect to 
!                                                                                             !  the constraint states (z)
!      TYPE(Morison_PartialDiscStatePConstrStateType),  INTENT(  OUT), OPTIONAL :: dXddz      ! Partial derivatives of discrete state
!                                                                                             !  equations (Xd) with respect to the 
!                                                                                             !  constraint states (z)
!      TYPE(Morison_PartialConstrStatePConstrStateType),INTENT(  OUT), OPTIONAL :: dZdz       ! Partial derivatives of constraint 
!                                                                                             ! state equations (Z) with respect to 
!                                                                                             !  the constraint states (z)
!      INTEGER(IntKi),                                  INTENT(  OUT)           :: ErrStat    ! Error status of the operation
!      CHARACTER(*),                                    INTENT(  OUT)           :: ErrMsg     ! Error message if ErrStat /= ErrID_None
!
!               
!         ! Initialize ErrStat
!         
!      ErrStat = ErrID_None         
!      ErrMsg  = ""               
!      
!      IF ( PRESENT( dYdz ) ) THEN
!      
!            ! Calculate the partial derivative of the output equations (Y) with respect to the constraint states (z) here:
!        
!         dYdz%DummyOutput%DummyConstrState = 0
!         
!      END IF
!      
!      IF ( PRESENT( dXdz ) ) THEN
!      
!            ! Calculate the partial derivative of the continuous state equations (X) with respect to the constraint states (z) here:
!         
!         dXdz%DummyContState%DummyConstrState = 0
!
!      END IF
!      
!      IF ( PRESENT( dXddz ) ) THEN
!
!            ! Calculate the partial derivative of the discrete state equations (Xd) with respect to the constraint states (z) here:
!
!         dXddz%DummyDiscState%DummyConstrState = 0
!
!      END IF
!      
!      IF ( PRESENT( dZdz ) ) THEN
!
!            ! Calculate the partial derivative of the constraint state equations (Z) with respect to the constraint states (z) here:
!         
!         dZdz%DummyConstrState%DummyConstrState = 0
!
!      END IF
!      
!
!END SUBROUTINE Morison_JacobianPConstrState

!----------------------------------------------------------------------------------------------------------------------------------
   
END MODULE Morison
!**********************************************************************************************************************************