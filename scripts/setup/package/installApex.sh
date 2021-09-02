#!/bin/bash

# Run as oracle user

ORAENV_ASK=NO
ORACLE_SID=${ORACLE_SID:-XE}

. oraenv 

cd $APEX_HOME

echo "Installing APEX"
sqlplus / as sysdba << EOF
  alter session set container = ${ORACLE_PDB:-XEPDB1};

  -- Install APEX
  @apexins.sql SYSAUX SYSAUX TEMP /i/

  -- APEX REST configuration
  @apex_rest_config_core.sql $PREFIX "${APEX_LISTENER_PWD:-$ORACLE_PWD}" "${APEX_REST_PUBLIC_USER_PWD:-$ORACLE_PWD}"

  -- Required for ORDS install
  alter user apex_public_user identified by "${APEX_PUBLIC_USER_PWD:-$ORACLE_PWD}" account unlock;

  -- Network ACL
  prompt Setup Network ACL
  begin
    for c1 in (
      select schema
      from sys.dba_registry
      where comp_id = 'APEX'
    ) loop
      sys.dbms_network_acl_admin.append_host_ace(
        host => '*'
        , ace => xs\$ace_type(
            privilege_list => xs\$name_list('connect')
            , principal_name => c1.schema
            , principal_type => xs_acl.ptype_db
        )
      );
    end loop;
    commit;
  end;
  /


  -- Setup APEX Admin account
  prompt Setup APEX Admin account
  begin
    apex_util.set_workspace(p_workspace => 'internal');
    apex_util.create_user(
      p_user_name => 'ADMIN'
      , p_email_address => '${APEX_ADMIN_EMAIL}'
      , p_web_password => '${APEX_ADMIN_PWD}'
      , p_developer_privs => 'ADMIN:CREATE:DATA_LOADER:EDIT:HELP:MONITOR:SQL'
      , p_change_password_on_first_use => 'N'
    );
    commit;
  end;
  /
EOF

cd $APEX_PATCH_HOME

echo "Installing APEX PATCHSET"
sqlplus / as sysdba << EOF
  alter session set container = ${ORACLE_PDB:-XEPDB1};
  @catpatch.sql 
  
EOF

echo "Copying APEX-Images"
cp -r $APEX_PATCH_HOME/images /opt/oracle/product/apex/images

