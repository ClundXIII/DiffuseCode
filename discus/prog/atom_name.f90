MODULE atom_name
!
CONTAINS
!*****7***************************************************************  
      CHARACTER(9) function at_name (iscat) 
!+                                                                      
!     This function builds the atom name as XX(iscat) to be             
!     able to distinguish between different atom types with             
!     the same name.                                                    
!-                                                                      
      USE discus_config_mod 
      USE crystal_mod 
      IMPLICIT none 
!                                                                       
       
!                                                                       
      CHARACTER(5) istr 
      INTEGER iscat, il, is 
!                                                                       
      INTEGER len_str 
!                                                                       
      IF (iscat.ge.100) then 
         WRITE (istr, 1000) iscat 
      ELSEIF (iscat.ge.10) then 
         WRITE (istr, 1100) iscat 
      ELSE 
         WRITE (istr, 1200) iscat 
      ENDIF 
!                                                                       
      il = len_str (cr_at_lis (iscat) ) 
      is = len_str (istr) 
!                                                                       
      at_name = cr_at_lis (iscat) (1:il) //istr (1:is) 
!                                                                       
 1000 FORMAT     ('(',I3,')') 
 1100 FORMAT     ('(',I2,')') 
 1200 FORMAT     ('(',I1,')') 
      END FUNCTION at_name                          
!*****7***************************************************************  
END MODULE atom_name
