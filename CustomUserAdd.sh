#!/bin/bash
#set -x
 
# Titulo        : "AdicionarUsuarioCIT.sh"
# Descricao     : Este script adiciona usuario nos servidores Linux da ATI.
# Autor         : Aecio Junior <aecio.junior@centralit.com.br>
# Data          : 22 de Julho de 2015.
# Versao        : 0.5
# Usage         : ssh -p7654 -T centralit@endereco.IP < ./AdicionarUsuarioCIT.sh
 
##----------------- Variaveis -----------------##
 
## Preencher conforme usuario a ser cadastrado.
Usuario="aecio.junior"
 
##------------------ Funcoes ------------------##
## Funcao para verificar existencia de um dado usuario
_VerificaUsuario(){
   local RC=0
   local Usuario=$1
   id $Usuario || local RC=$?
   return $RC
}
 
## Funcao para cadastrar usuario
_AdicionaUsuario(){
   local RC=0
   local Usuario=$1
   local Comentario="ANALISTA DE SUPORTE - CENTRAL-IT"
   local DirHome=/home/$Usuario
   local Shell="/bin/bash"
   sudo /usr/sbin/useradd --create-home --comment "$Comentario" --home "$DirHome" --shell "$Shell" $Usuario || local RC=$?
   return $RC
}
 
## Atualiza senha do usuario para senha inicial padrao
_AtualizaSenha(){
   local RC=0
   local Usuario=$1
   local SenhaInicial='p@ssw0rd'
   echo "$Usuario:$SenhaInicial" | sudo /usr/sbin/chpasswd || local RC=$?
   return $RC
}
 
## Verifica se o acesso ssh esta autorizado para dado usuario
_VerificaSSH(){
   local RC=0
   local Usuario=$1
   sudo grep -E "^AllowUsers.*$Usuario" /etc/ssh/sshd_config || local RC=$?
   return $RC
}
 
## Realiza backup de arquivo de configuracao fornecido como argumento
_BackupArquivoConfiguracao(){
   local RC=0
   local Arquivo=$1
   sudo cp -Rfa $Arquivo{,.CentralIT.`date "+%Y%m%d-%H%M"`} || local RC=$?
   return $RC
}
 
## Acrescenta usuario no arq. config. do SSH autorizando acesso
_AutorizarSSH(){
   local RC=0
   local Usuario=$1
   sudo sed -i "/^AllowUsers/s/.*/& $Usuario/" /etc/ssh/sshd_config || local RC=$?
   return $RC
}
 
## Reinicia o ssh daemon
_ReiniciarSSH(){
   local RC=0
 
   { sudo test -f /etc/init.d/ssh && sudo /etc/init.d/ssh restart; } || \
   { sudo test -f /etc/init.d/sshd && sudo /etc/init.d/sshd restart; } || \
   local RC=$?
 
   return $RC
}
 
## Verifica se dado usuario encontra-se no sudo
_VerificaSUDO(){
   local RC=0
   local Usuario=$1
   sudo grep -E -e "richardson.*$1" -e "aecio.*$1" -e "carlos.onorato.*$1" /etc/sudoers || local RC=$?
   return $RC
}
 
## Acrescenta usuario CIT no sudoers
_AutorizarSUDO(){
   local RC=0
   local Usuario=$1
   sudo sed -i "/aecio\|richardson\|onorato/s/.*/&,$Usuario/" /etc/sudoers || local RC=$?
   return $RC
}
 
## Muda atributos de bit imutavel (on/off)
_MudaAtributos(){
 
   local RC=0
   local ST="$1"
   if [ "$ST" == "on" ]; then
      local State='+i'
   elif [ "$ST" == "off" ]; then
      local State='-i'
   fi
 
   sudo chattr $State /etc/ssh/sshd_config || local RC=$?
   sudo chattr $State /etc/sudoers || local RC=$?
   sudo chattr $State /etc/passwd || local RC=$?
   sudo chattr $State /etc/shadow || local RC=$?
   sudo chattr $State /etc/gshadow || local RC=$?
   sudo chattr $State /etc/group || local RC=$?
 
   return $RC
}
 
##------------------- Inicio do Script --------------------#
 
### Desativa bit imutavel
sudo test -f /root/unlock && sudo /root/unlock || { _MudaAtributos off || echo erro desativando atributos; }
 
### Verifica se o usuario existe, do contrario, adicionar.
if _VerificaUsuario $Usuario
then
   echo Usuario ja cadastrado
else
   if _AdicionaUsuario $Usuario
   then
      echo usuario adicionado com sucesso
      if _AtualizaSenha $Usuario
      then
         echo senha atualizada conforme padrao inicial
      else
         echo erro na atualizacao da senha. fazer manualemnte
      fi
   else
      echo erro no cadastro do usuario
   fi
fi
 
### Verifica se o acesso ssh esta autorizado ao usuario, senão, autorizar.
if _VerificaSSH $Usuario
then
   if _ReiniciarSSH
   then
      echo ssh daemon reinciado por precaucao
   else
      echo erro reiniciando ssh
   fi
else
   if _BackupArquivoConfiguracao /etc/ssh/sshd_config
   then
      if _AutorizarSSH $Usuario
      then
         echo usuario adicionado no ssh
         if _ReiniciarSSH
         then
            echo ssh reinciado apos adicao de usuario na configuracao
         else
            echo problemas reinciando ssh
         fi
      else
         echo erro autorizando ssh
      fi
   else
      echo erro backupeando arquivo de configuracao /etc/ssh/sshd_config
   fi
fi
 
### Verifica se o usuario esta no sudosh, senão, adicionar.
if _VerificaSUDO $Usuario
then
   echo Usuario ja cadastrado no sudo
else
   if _BackupArquivoConfiguracao /etc/sudoers
   then
      echo arquivo sudoers backupeado
      if _AutorizarSUDO $Usuario
      then
         echo sudo autorizado
      else
         echo erro autorizando o sudo
      fi
   else
      echo erro no backup do arquivo
   fi
fi
 
### Ativa bit imutavel
sudo test -f /root/lock && sudo /root/lock || { _MudaAtributos on || echo erro ativando atributos; }
 
#-------------------- Fim do Script --------------------#
