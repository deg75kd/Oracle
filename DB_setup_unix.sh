

# set environment scripts
/nomove/app/oracle/setenv 

# oratab file
/etc/oratab 

#
sudo /nomove/app/oracle/db/11g/5/root.sh

# create links to parameter and password files
ln -s /move/blcfdsp_adm01/admin/pfile/initblcfdsp.ora initblcfdsp.ora 
ln -s /move/blcfdsp_adm01/admin/pfile/spfileblcfdsp.ora spfileblcfdsp.ora
ln -s /move/blcfdsp_adm01/admin/pfile/orapwblcfdsp orapwblcfdsp

# relink Oracle binaries
$ORACLE_HOME/bin/relink all

# agent installer
# must be running Xserver
cd /nomove/app/oracle/agent12c/core/12.1.0.3.0/oui/bin
xclock
./runInstaller -deinstall

