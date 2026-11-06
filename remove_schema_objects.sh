#!/bin/bash

##############################################################################
# Script : remove_schema_objects.sh
# Objetivo: Remover todos os objetos de um schema Oracle
# Mantém o schema (usuário)
# Compatível: Oracle 19c / Multitenant
##############################################################################

clear

echo ""
echo "===================================================="
echo " REMOCAO DE OBJETOS DE UM SCHEMA "
echo "===================================================="
echo ""

##############################################################################
# PDB
##############################################################################
while true
do
   read -p "Informe a PDB: " PDB

   PDB=$(echo "$PDB" | tr '[:lower:]' '[:upper:]')

   if [ -z "$PDB" ]
   then
      echo ""
      echo "ERRO: A PDB deve ser informada."
      echo ""
      continue
   fi

   break
done

##############################################################################
# OWNER
##############################################################################
while true
do
   read -p "Informe o OWNER: " OWNER

   OWNER=$(echo "$OWNER" | tr '[:lower:]' '[:upper:]')

   if [ -z "$OWNER" ]
   then
      echo ""
      echo "ERRO: O OWNER deve ser informado."
      echo ""
      continue
   fi

   break
done

##############################################################################
# SCHEMAS PROTEGIDOS
##############################################################################
case "$OWNER" in
   SYS|SYSTEM|DBSNMP|SYSMAN|XDB|OUTLN)
      echo ""
      echo "ERRO: Schema protegido."
      echo ""
      exit 1
      ;;
esac

LOG=DROP_${OWNER}_$(date +%Y%m%d_%H%M%S).log

echo ""
echo "Validando PDB e OWNER..."
echo ""

##############################################################################
# VALIDA PDB
##############################################################################
EXISTE_PDB=$(sqlplus -s "/ as sysdba" <<EOF
SET PAGES 0
SET FEEDBACK OFF
SET VERIFY OFF
SET HEADING OFF

SELECT COUNT(*)
FROM V\\\$PDBS
WHERE NAME='$PDB';

EXIT
EOF
)

if [ "$(echo $EXISTE_PDB | xargs)" = "0" ]
then
   echo ""
   echo "ERRO: PDB $PDB nao encontrada."
   echo ""
   exit 1
fi

##############################################################################
# VALIDA OWNER
##############################################################################
EXISTE_OWNER=$(sqlplus -s "/ as sysdba" <<EOF
SET PAGES 0
SET FEEDBACK OFF
SET VERIFY OFF
SET HEADING OFF

ALTER SESSION SET CONTAINER=$PDB;

SELECT COUNT(*)
FROM DBA_USERS
WHERE USERNAME='$OWNER';

EXIT
EOF
)

if [ "$(echo $EXISTE_OWNER | tail -1 | xargs)" = "0" ]
then
   echo ""
   echo "ERRO: OWNER $OWNER nao existe na PDB $PDB."
   echo ""
   exit 1
fi

##############################################################################
# RESUMO DOS OBJETOS
##############################################################################
sqlplus -s "/ as sysdba" <<EOF

SET PAGES 200
SET LINES 200
SET FEEDBACK OFF

ALTER SESSION SET CONTAINER=$PDB;

PROMPT
PROMPT ==========================================
PROMPT RESUMO DOS OBJETOS
PROMPT ==========================================
PROMPT

COLUMN OBJECT_TYPE FORMAT A30
COLUMN QTD FORMAT 999999

SELECT OBJECT_TYPE,
       COUNT(*) QTD
FROM DBA_OBJECTS
WHERE OWNER='$OWNER'
GROUP BY OBJECT_TYPE
ORDER BY OBJECT_TYPE;

PROMPT

SELECT 'TOTAL OBJETOS' DESCRICAO,
       COUNT(*) QTD
FROM DBA_OBJECTS
WHERE OWNER='$OWNER';

EXIT
EOF

##############################################################################
# CONFIRMACAO
##############################################################################
echo ""

while true
do

   read -p "Confirma exclusao dos objetos do schema $OWNER na PDB $PDB ? (S/N): " RESP

   RESP=$(echo "$RESP" | tr '[:lower:]' '[:upper:]')

   case "$RESP" in
      S|N)
         break
         ;;
      *)
         echo ""
         echo "Digite apenas S ou N."
         echo ""
         ;;
   esac

done

if [ "$RESP" = "N" ]
then
   echo ""
   echo "Operacao cancelada."
   echo ""
   exit 0
fi

echo ""
echo "Executando..."
echo ""

##############################################################################
# REMOCAO DOS OBJETOS
##############################################################################
sqlplus -s "/ as sysdba" <<EOF | tee $LOG

SET SERVEROUTPUT ON SIZE UNLIMITED
SET FEEDBACK OFF
SET PAGES 200
SET LINES 200

ALTER SESSION SET CONTAINER=$PDB;

DECLARE

    V_SQL VARCHAR2(4000);

BEGIN

    DBMS_OUTPUT.PUT_LINE('==========================================');
    DBMS_OUTPUT.PUT_LINE('INICIO: '||
                         TO_CHAR(SYSDATE,'DD/MM/YYYY HH24:MI:SS'));
    DBMS_OUTPUT.PUT_LINE('OWNER : $OWNER');
    DBMS_OUTPUT.PUT_LINE('==========================================');

    --------------------------------------------------------------------------
    -- MATERIALIZED VIEWS
    --------------------------------------------------------------------------
    FOR R IN (
        SELECT OWNER,MVIEW_NAME
        FROM DBA_MVIEWS
        WHERE OWNER='$OWNER'
    ) LOOP

        BEGIN
            V_SQL := 'DROP MATERIALIZED VIEW '||
                     R.OWNER||'.'||R.MVIEW_NAME;

            DBMS_OUTPUT.PUT_LINE(V_SQL||';');

            EXECUTE IMMEDIATE V_SQL;

        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE(SQLERRM);
        END;
    END LOOP;

    --------------------------------------------------------------------------
    -- VIEWS
    --------------------------------------------------------------------------
    FOR R IN (
        SELECT OWNER,OBJECT_NAME
        FROM DBA_OBJECTS
        WHERE OWNER='$OWNER'
        AND OBJECT_TYPE='VIEW'
    ) LOOP
        BEGIN
            V_SQL := 'DROP VIEW '||
                     R.OWNER||'.'||R.OBJECT_NAME;

            DBMS_OUTPUT.PUT_LINE(V_SQL||';');

            EXECUTE IMMEDIATE V_SQL;

        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE(SQLERRM);
        END;
    END LOOP;

    --------------------------------------------------------------------------
    -- PACKAGES
    --------------------------------------------------------------------------
    FOR R IN (
        SELECT OWNER,OBJECT_NAME
        FROM DBA_OBJECTS
        WHERE OWNER='$OWNER'
        AND OBJECT_TYPE='PACKAGE'
    ) LOOP
        BEGIN
            V_SQL := 'DROP PACKAGE '||
                     R.OWNER||'.'||R.OBJECT_NAME;

            DBMS_OUTPUT.PUT_LINE(V_SQL||';');

            EXECUTE IMMEDIATE V_SQL;

        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE(SQLERRM);
        END;
    END LOOP;

    --------------------------------------------------------------------------
    -- PROCEDURES
    --------------------------------------------------------------------------
    FOR R IN (
        SELECT OWNER,OBJECT_NAME
        FROM DBA_OBJECTS
        WHERE OWNER='$OWNER'
        AND OBJECT_TYPE='PROCEDURE'
    ) LOOP
        BEGIN
            V_SQL := 'DROP PROCEDURE '||
                     R.OWNER||'.'||R.OBJECT_NAME;

            DBMS_OUTPUT.PUT_LINE(V_SQL||';');

            EXECUTE IMMEDIATE V_SQL;

        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE(SQLERRM);
        END;
    END LOOP;

    --------------------------------------------------------------------------
    -- FUNCTIONS
    --------------------------------------------------------------------------
    FOR R IN (
        SELECT OWNER,OBJECT_NAME
        FROM DBA_OBJECTS
        WHERE OWNER='$OWNER'
        AND OBJECT_TYPE='FUNCTION'
    ) LOOP
        BEGIN
            V_SQL := 'DROP FUNCTION '||
                     R.OWNER||'.'||R.OBJECT_NAME;

            DBMS_OUTPUT.PUT_LINE(V_SQL||';');

            EXECUTE IMMEDIATE V_SQL;

        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE(SQLERRM);
        END;
    END LOOP;

    --------------------------------------------------------------------------
    -- TRIGGERS
    --------------------------------------------------------------------------
    FOR R IN (
        SELECT OWNER,TRIGGER_NAME
        FROM DBA_TRIGGERS
        WHERE OWNER='$OWNER'
    ) LOOP
        BEGIN
            V_SQL := 'DROP TRIGGER '||
                     R.OWNER||'.'||R.TRIGGER_NAME;

            DBMS_OUTPUT.PUT_LINE(V_SQL||';');

            EXECUTE IMMEDIATE V_SQL;

        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE(SQLERRM);
        END;
    END LOOP;

    --------------------------------------------------------------------------
    -- SEQUENCES
    --------------------------------------------------------------------------
    FOR R IN (
        SELECT SEQUENCE_OWNER,
               SEQUENCE_NAME
        FROM DBA_SEQUENCES
        WHERE SEQUENCE_OWNER='$OWNER'
    ) LOOP
        BEGIN
            V_SQL := 'DROP SEQUENCE '||
                     R.SEQUENCE_OWNER||'.'||R.SEQUENCE_NAME;

            DBMS_OUTPUT.PUT_LINE(V_SQL||';');

            EXECUTE IMMEDIATE V_SQL;

        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE(SQLERRM);
        END;
    END LOOP;

    --------------------------------------------------------------------------
    -- SYNONYMS
    --------------------------------------------------------------------------
    FOR R IN (
        SELECT OWNER,SYNONYM_NAME
        FROM DBA_SYNONYMS
        WHERE OWNER='$OWNER'
    ) LOOP
        BEGIN
            V_SQL := 'DROP SYNONYM '||
                     R.OWNER||'.'||R.SYNONYM_NAME;

            DBMS_OUTPUT.PUT_LINE(V_SQL||';');

            EXECUTE IMMEDIATE V_SQL;

        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE(SQLERRM);
        END;
    END LOOP;

    --------------------------------------------------------------------------
    -- LIBRARIES
    --------------------------------------------------------------------------
    FOR R IN (
        SELECT OWNER,OBJECT_NAME
        FROM DBA_OBJECTS
        WHERE OWNER='$OWNER'
        AND OBJECT_TYPE='LIBRARY'
    ) LOOP
        BEGIN
            V_SQL := 'DROP LIBRARY '||
                     R.OWNER||'.'||R.OBJECT_NAME;

            DBMS_OUTPUT.PUT_LINE(V_SQL||';');

            EXECUTE IMMEDIATE V_SQL;

        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE(SQLERRM);
        END;
    END LOOP;

    --------------------------------------------------------------------------
    -- TYPES
    --------------------------------------------------------------------------
    FOR R IN (
        SELECT OWNER,TYPE_NAME
        FROM DBA_TYPES
        WHERE OWNER='$OWNER'
    ) LOOP
        BEGIN
            V_SQL := 'DROP TYPE '||
                     R.OWNER||'.'||R.TYPE_NAME||
                     ' FORCE';

            DBMS_OUTPUT.PUT_LINE(V_SQL||';');

            EXECUTE IMMEDIATE V_SQL;

        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE(SQLERRM);
        END;
    END LOOP;

    --------------------------------------------------------------------------
    -- TABLES
    --------------------------------------------------------------------------
    FOR R IN (
        SELECT OWNER,TABLE_NAME
        FROM DBA_TABLES
        WHERE OWNER='$OWNER'
    ) LOOP
        BEGIN
            V_SQL := 'DROP TABLE '||
                     R.OWNER||'.'||R.TABLE_NAME||
                     ' CASCADE CONSTRAINTS PURGE';

            DBMS_OUTPUT.PUT_LINE(V_SQL||';');

            EXECUTE IMMEDIATE V_SQL;

        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE(SQLERRM);
        END;
    END LOOP;

    DBMS_OUTPUT.PUT_LINE('==========================================');
    DBMS_OUTPUT.PUT_LINE('FIM DA REMOCAO');
    DBMS_OUTPUT.PUT_LINE('==========================================');

END;
/

PROMPT
PROMPT ==========================================
PROMPT LIMPANDO RECYCLE BIN
PROMPT ==========================================
PROMPT

PURGE DBA_RECYCLEBIN;

PROMPT
PROMPT ==========================================
PROMPT VALIDACAO FINAL
PROMPT ==========================================
PROMPT

COLUMN OBJECT_TYPE FORMAT A30
COLUMN QTD FORMAT 999999

SELECT OBJECT_TYPE,
       COUNT(*) QTD
FROM DBA_OBJECTS
WHERE OWNER='$OWNER'
AND OBJECT_TYPE IN
(
   'TABLE',
   'VIEW',
   'MATERIALIZED VIEW',
   'PACKAGE',
   'PACKAGE BODY',
   'PROCEDURE',
   'FUNCTION',
   'SEQUENCE',
   'TRIGGER',
   'TYPE',
   'INDEX',
   'SYNONYM',
   'LIBRARY'
)
GROUP BY OBJECT_TYPE
ORDER BY OBJECT_TYPE;

DECLARE

   V_QTD NUMBER;

BEGIN

   SELECT COUNT(*)
   INTO V_QTD
   FROM DBA_OBJECTS
   WHERE OWNER='$OWNER'
   AND OBJECT_TYPE IN
   (
      'TABLE',
      'VIEW',
      'MATERIALIZED VIEW',
      'PACKAGE',
      'PACKAGE BODY',
      'PROCEDURE',
      'FUNCTION',
      'SEQUENCE',
      'TRIGGER',
      'TYPE',
      'INDEX',
      'SYNONYM',
      'LIBRARY'
   );

   DBMS_OUTPUT.PUT_LINE('');
   DBMS_OUTPUT.PUT_LINE('------------------------------------------');

   IF V_QTD = 0 THEN

      DBMS_OUTPUT.PUT_LINE(
      'SUCESSO: Nenhum objeto de aplicacao encontrado para o schema $OWNER.');

      DBMS_OUTPUT.PUT_LINE(
      'Schema pronto para novo Data Pump (IMPDP).');

   ELSE

      DBMS_OUTPUT.PUT_LINE(
      'ATENCAO: Ainda existem '||V_QTD||
      ' objeto(s) no schema $OWNER.');

   END IF;

   DBMS_OUTPUT.PUT_LINE('------------------------------------------');
   DBMS_OUTPUT.PUT_LINE('');

END;
/

PROMPT
PROMPT ==========================================
PROMPT CONSULTA FINAL
PROMPT ==========================================
PROMPT

SELECT CASE
         WHEN COUNT(*) = 0
         THEN 'SCHEMA LIMPO - NENHUM OBJETO ENCONTRADO'
         ELSE 'SCHEMA POSSUI OBJETOS'
       END AS STATUS
FROM DBA_OBJECTS
WHERE OWNER='$OWNER'
AND OBJECT_TYPE IN
(
   'TABLE',
   'VIEW',
   'MATERIALIZED VIEW',
   'PACKAGE',
   'PACKAGE BODY',
   'PROCEDURE',
   'FUNCTION',
   'SEQUENCE',
   'TRIGGER',
   'TYPE',
   'INDEX',
   'SYNONYM',
   'LIBRARY'
);

EXIT
EOF

echo ""
echo "===================================================="
echo "Processamento concluido."
echo "Log gerado: $LOG"
echo "===================================================="
echo ""
