import-module CustomMSSQL -force

$Conexao = New-MSSQLSession ".\RRG"

$r = $Conexao.evaluatePolicy("*Read*Only*",".\RRG")