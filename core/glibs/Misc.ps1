#Mescla duas hashtables, atualizando a $Dest com base nas opcoes de $Src.
Function MergeHashTables($Dest,$Src, [switch]$Recurse = $false) {
	
	#para cada key da hashtable de destino
	@($Dest.Keys) | %{
		$DestKey 	= $_;
		$DestValue	= $Dest[$DestKey]
		
		#Se a key existir na origem, então usa atualiza o valor da origem no destino.
		if($Src.Contains($DestKey)){
			$SrcValue = $Src[$DestKey];
			
			#Se a key de origem e de destino são uma hashtable.
			if($Recurse){
				if($DestValue -is [hashtable] -and $SrcValue -is [hashtable]){
					#Chama a propria funcaio para  mesclar
					$SrcValue = MergeHashTables -Dest $DestValue -Src $SrcValue
				}
			}

			#Atualiza a key correpondente de destino com o valor da origem
			$Dest[$DestKey] = $SrcValue;
		}
		
		
	}
	
	return $Dest;
}

#http://stackoverflow.com/questions/35116636/bit-shifting-in-powershell-2-0
function bitshift {
    param(
		[uint64]$x,
        [int]$Left = $null,
        [int]$Right = $null
    ) 

    $shift = if($Left)
    { 
        $Left
    }	
    else
    {
        -$Right
    }

    return [uint64][math]::Floor($x * [math]::Pow(2,$shift))
}

#Converte um ip ou mascara numérico para representação textual!
#Solucao adapatada de: http://stackoverflow.com/questions/32028166/convert-cidr-notation-into-ip-range
#Thanks Sami Kuhmonen
Function NumIp2String {
	param([uint64]$numip)
	
	return [string](bitshift $numip -Right 24) `
			+'.'+ ( (bitshift $numip -Right 16) -band 0xFF ) `
			+'.'+ ( (bitshift $numip -Right 8) -band 0xFF ) `
			+'.'+ ( $numip -band 0xFF )
	
}

#Extrai informações de rede do IP. O Ip pode ser informado no formato x.x.x.x/dd ou x.x.x.x/mmm.mmm.mmm.mmm
#Solucao adapatada de: http://stackoverflow.com/questions/32028166/convert-cidr-notation-into-ip-range
#Thanks Sami Kuhmonen
Function GetIpNetInfo {
	param([string]$ip)
	
	#string IP = "5.39.40.96/27";
	#string[] parts = IP.Split('.', '/');
	<#
	uint ipnum = (Convert.ToUInt32(parts[0]) << 24) |
		(Convert.ToUInt32(parts[1]) << 16) |
		(Convert.ToUInt32(parts[2]) << 8) |
		Convert.ToUInt32(parts[3]);
	int maskbits = Convert.ToInt32(parts[4]);
	uint mask = 0xffffffff;
	mask <<= (32 - maskbits);

	uint ipstart = ipnum & mask;
	uint ipend = ipnum | (mask ^ 0xffffffff);

	Console.WriteLine(toip(ipstart) + " - " + toip(ipend));
	
	#>
	
	$IpParts = $ip.Split( @('/') );
	$parts	 = $IpParts[0].split(".")
	
	#Gera a representação do IP em formato numérico...
	[uint32]$ipnum = 	[Convert]::ToUint32(  (bitshift $parts[0] -Left 24) ) 	-bor `
						[Convert]::ToUInt32(  (bitshift $parts[1] -Left 16) ) 	-bor `
						[Convert]::ToUInt32(  (bitshift $parts[2] -Left 8)) 	-bor `
						[Convert]::ToUInt32(  ( $parts[3] ) )

	
	[byte]$maskBits = $null #irá guardar o número de bits da máscara...
	
	#Verifica se a máscara foi informada na notação cidr...
	$maskString = $IpParts[1];
	if($maskString.trim() -match '^\d?\d$'){
		#Converte para número...
		$maskBits = [byte]$maskString;
	} else {
		#A máscara foi informada no formato xxx.xxx.xxx.xxx
		$maskParts = $maskString.split(".");
		
		#Os octetos podem somente conter estes valores. (Exx.: 1000000 -> 128 | 11000000 --> 192). O valor 10100000 não pode (os 1 tem de ser sequenciais.)
		$ValidRanges = 0,128,192,224,240,248,252,254,255
		$bitCount = 0;
		$previousOctect = 255;
		$octNum = 0;
		$maskParts | %{
			$octNum++;
			$Byte = [byte]$_; #Converte o valor para um byte!
			
			#Se o octeto anterior não foi 255 (11111111), então pode somente 0!
			if($_ -ne 0 -and $previousOctect -ne 255){
				throw "INVALID_MASK_OCTECT: Pos:$octNum Value:$_ ($maskString)"
			}
			
			if($ValidRanges -NotContains $Byte){
				throw "INVALID_MASK_OCTECT_RANGE: Pos:$octNum Value:$_ ($maskString)"
			}
			
			$previousOctect = $Byte;
			
			$bitCount += [convert]::toString([byte]$Byte,2).replace('0','').length;
		}
		
		$maskBits = $bitCount;
	}
	
	if($maskBits -le 0 -or $maskBits -ge 32){
		throw "INVALID_MASK_BIT_COUNT: $maskBits"
	}
	
	#Obtém a representacao numérica da mascara
	#Faz um and com o max value do int32, pois so improta os ultimos 32 bits!
	[uint32]$maskNum = (bitshift ([UInt32]::MaxValue) -Left (32 - $maskBits)) -band [UInt32]::MaxValue;
	
	#Ontém o ip da rede
	$netIpNum = $ipnum -band $maskNum;
	
	return NEw-Object PsObject -Prop @{
							NetworkMask	= NumIp2String $maskNum
							NetworkIp 	= NumIp2String $netIpNum
							IP			= NumIp2String $ipnum
							Numerics	= (New-Object PsObject  -Prop @{
													NetworkMask 	= $maskNum
													NetworkIp		= $netIpNum
													IP				= $ipnum
												}
										)
					}
	
}