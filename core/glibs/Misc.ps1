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