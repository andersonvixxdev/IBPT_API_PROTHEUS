#Include "Totvs.ch"

/*/{Protheus.doc} u_F092Lin
    Consulta a API do IBPT para o registo atualmente posicionado na tabela CLK (FISA092).
    @type  Function
    @author Seu Nome
    @since  16/10/2026
/*/
User Function F092Lin()
	Local cCodigo := Iif(!Empty(CLK->CLK_CODNCM), AllTrim(CLK->CLK_CODNCM), AllTrim(CLK->CLK_CODNBS))
	Local cTipo   := Iif(!Empty(CLK->CLK_CODNCM), "P", "S")
	Local cUF     := AllTrim(CLK->CLK_UF)
	Local nEx     := Val(CLK->CLK_EX)
	Local jDados  := Nil

	If Empty(cCodigo) .Or. Empty(cUF)
		MsgAlert("Selecione um registo com NCM/NBS e UF válidos.", "IBPT FISA092")
		Return .F.
	EndIf

	If !MsgYesNo("Deseja consultar a API IBPT para o item " + cCodigo + " (" + cUF + ")?", "Atualizar IBPT")
		Return .F.
	EndIf

	FWMsgRun(, {|oSay| jDados := U_ConsIBPT(cTipo, cCodigo, cUF, nEx, CLK->CLK_DESCR, "UN", 1.00)}, ;
		"Aguarde...", "A consultar API IBPT...")

	If jDados != Nil
		U_GravaCLK(jDados, cTipo, cUF, cCodigo, cValToChar(nEx))
		MsgInfo("Tabela CLK atualizada com sucesso para " + cCodigo + "!", "FISA092")
	Else
		MsgStop("Falha ao comunicar com a API do IBPT. Verifique o diagnóstico apresentado.", "Erro")
	EndIf

Return .T.

/*/{Protheus.doc} u_F092All
    Varre os NCMs distintos cadastrados no SB1 e atualiza/alimenta a tabela CLK via API.
    @type  Function
    @author Seu Nome
    @since  16/10/2026
/*/
User Function F092All()
	Local cUF       := SuperGetMV("MV_ESTADO", .F., "SP")
	Local cAliasQry := GetNextAlias()
	Local cQuery    := ""
	Local nTotal    := 0
	Local nAtu      := 0

	If !MsgYesNo("Deseja sincronizar as alíquotas do IBPT para todos os NCMs dos produtos ativos nesta filial (" + cUF + ")?", "Sincronização em Lote")
		Return .F.
	EndIf

	cQuery := "SELECT DISTINCT B1_POSIPI, B1_EX_NCM, MIN(B1_DESC) AS B1_DESC "
	cQuery += "FROM " + RetSqlName("SB1") + " "
	cQuery += "WHERE D_E_L_E_T_ = ' ' AND B1_MSBLQL != '1' AND B1_POSIPI <> '' "
	cQuery += "GROUP BY B1_POSIPI, B1_EX_NCM"

	cQuery := ChangeQuery(cQuery)
	DbUseArea(.T., "TOPCONN", TcGenQry(,,cQuery), cAliasQry, .F., .T.)

	Count To nTotal
	(cAliasQry)->(DbGoTop())

	If nTotal == 0
		(cAliasQry)->(DbCloseArea())
		MsgInfo("Nenhum NCM encontrado na tabela de produtos (SB1).", "Aviso")
		Return .F.
	EndIf

	FWMsgRun(, {|oSay| nAtu := F092Proc(oSay, cAliasQry, cUF, nTotal)}, ;
		"A processar FISA092", "A atualizar tabela CLK via API IBPT...")

	(cAliasQry)->(DbCloseArea())
	MsgInfo("Sincronização finalizada! Registos processados: " + cValToChar(nAtu) + "/" + cValToChar(nTotal), "Concluído")
Return .T.

/*/{Protheus.doc} F092Proc
    Função estática auxiliar para iterar os registos com interface visual responsiva.
/*/
Static Function F092Proc(oSay, cAliasQry, cUF, nTotal)
	Local jDados := Nil
	Local nAtu   := 0

	While (cAliasQry)->(!Eof())
		If oSay != Nil
			oSay:SetText("NCM: " + (cAliasQry)->B1_POSIPI + " (" + cValToChar(nAtu + 1) + "/" + cValToChar(nTotal) + ")")
			ProcessMessages()
		EndIf

		jDados := U_ConsIBPT("P", (cAliasQry)->B1_POSIPI, cUF, Val((cAliasQry)->B1_EX_NCM), (cAliasQry)->B1_DESC, "UN", 1.00)

		If jDados != Nil
			U_GravaCLK(jDados, "P", cUF, (cAliasQry)->B1_POSIPI, (cAliasQry)->B1_EX_NCM)
			nAtu++
		EndIf

		Sleep(120) // Pausa de segurança para respeitar a taxa de requisições da API
		(cAliasQry)->(DbSkip())
	EndDo

Return nAtu

/*/{Protheus.doc} u_GravaCLK
    Grava ou atualiza os dados na tabela CLK (FISA092).
    @type  Function
    @author Seu Nome
    @since  16/10/2026
/*/
User Function GravaCLK(jDados, cTipo, cUF, cCodigo, cEx)
	Local dVigIni  := CTOD("  /  /    ")
	Local dVigFim  := CTOD("  /  /    ")
	Local cChvNcm  := ""
	Local cChvEx   := ""
	Local cChvUF   := PadR(AllTrim(cUF), TamSX3("CLK_UF")[1])
	Local lFound   := .F.
	Local cDataIni := ""
	Local cDataFim := ""

	// No padrão Protheus, se a exceção for 0 ou vazia grava espaços em branco
	If Val(cEx) > 0
		cChvEx := PadR(AllTrim(cValToChar(Val(cEx))), TamSX3("CLK_EX")[1])
	Else
		cChvEx := Space(TamSX3("CLK_EX")[1])
	EndIf

	// Tratamento das datas de vigência (ISO YYYY-MM-DD ou DD/MM/AAAA)
	If jDados:HasProperty("VigenciaInicio") .And. !Empty(jDados["VigenciaInicio"])
		cDataIni := Left(AllTrim(jDados["VigenciaInicio"]), 10)
		If "-" $ cDataIni
			dVigIni := StoD(StrTran(cDataIni, "-", ""))
		Else
			dVigIni := CToD(cDataIni)
		EndIf
	EndIf

	If jDados:HasProperty("VigenciaFim") .And. !Empty(jDados["VigenciaFim"])
		cDataFim := Left(AllTrim(jDados["VigenciaFim"]), 10)
		If "-" $ cDataFim
			dVigFim := StoD(StrTran(cDataFim, "-", ""))
		Else
			dVigFim := CToD(cDataFim)
		EndIf
	EndIf

	DbSelectArea("CLK")

	If cTipo == "P"
		cChvNcm := PadR(StrTran(cCodigo, ".", ""), TamSX3("CLK_CODNCM")[1])
		// Índice 2: CLK_FILIAL + CLK_CODNCM + CLK_EX + CLK_UF + DTOS(CLK_DTINIV) + DTOS(CLK_DTFIMV)
		CLK->(DbSetOrder(2))
		lFound := CLK->(DbSeek(xFilial("CLK") + cChvNcm + cChvEx + cChvUF + DtoS(dVigIni) + DtoS(dVigFim)))
	Else
		cChvNcm := PadR(StrTran(cCodigo, ".", ""), TamSX3("CLK_CODNBS")[1])
		// Índice 1: CLK_FILIAL + CLK_CODNBS + CLK_EX + CLK_UF + DTOS(CLK_DTINIV) + DTOS(CLK_DTFIMV)
		CLK->(DbSetOrder(1))
		lFound := CLK->(DbSeek(xFilial("CLK") + cChvNcm + cChvEx + cChvUF + DtoS(dVigIni) + DtoS(dVigFim)))
	EndIf

	RecLock("CLK", !lFound)
	CLK->CLK_FILIAL := xFilial("CLK")

	If cTipo == "P"
		CLK->CLK_CODNCM := cChvNcm
		CLK->CLK_CODNBS := Space(TamSX3("CLK_CODNBS")[1])
	Else
		CLK->CLK_CODNCM := Space(TamSX3("CLK_CODNCM")[1])
		CLK->CLK_CODNBS := cChvNcm
	EndIf

	CLK->CLK_EX     := cChvEx
	CLK->CLK_UF     := cChvUF
	CLK->CLK_DESCR  := Left(jDados["Descricao"], TamSX3("CLK_DESCR")[1])
	CLK->CLK_ALQNAC := jDados["Nacional"]
	CLK->CLK_ALQIMP := jDados["Importado"]
	CLK->CLK_ALQEST := jDados["Estadual"]
	CLK->CLK_ALQMUN := jDados["Municipal"]
	CLK->CLK_DTINIV := dVigIni
	CLK->CLK_DTFIMV := dVigFim
	CLK->CLK_VERSAO := Left(jDados["Versao"], TamSX3("CLK_VERSAO")[1])
	CLK->CLK_FONTE  := Left(Iif(Empty(jDados["Fonte"]), "IBPT", jDados["Fonte"]), TamSX3("CLK_FONTE")[1])

	If CLK->(FieldPos("CLK_CHAVE")) > 0
		CLK->CLK_CHAVE := Left(jDados["Chave"], TamSX3("CLK_CHAVE")[1])
	EndIf
	CLK->(MsUnlock())

Return .T.

/*/{Protheus.doc} u_ConsIBPT
    Client REST HTTP que consome a API do IBPT com retorno de diagnóstico completo.
    @type  Function
    @author Seu Nome
    @since  16/10/2026
/*/
User Function ConsIBPT(cTipo, cCodigo, cUF, nEx, cDesc, cUM, nValor, cGtin)
	Local oRest       := Nil
	Local cEndpoint   := ""
	Local aHeader     := {}
	Local cToken      := SuperGetMV("MV_XTOKIBP", .F., "zDAcvTi640YjzallI2TbcmGFOaRSbSbYT6uGfsix1cByrIdQeRrqpFBWIeP_uz9F")
	Local cCnpj       := AllTrim(SM0->M0_CGC)
	Local jRet        := Nil
	Local cResponse   := ""
	Local oJsonParser := JsonObject():New()
	Local cParamUrl   := ""

	// Atribuições com valores por omissão
	cTipo  := Iif(cTipo == Nil, "P", cTipo)
	nEx    := Iif(nEx == Nil, 0, nEx)
	cDesc  := Iif(cDesc == Nil, "MERCADORIA", cDesc)
	cUM    := Iif(cUM == Nil, "UN", cUM)
	nValor := Iif(nValor == Nil, 1.00, nValor)
	cGtin  := Iif(cGtin == Nil, "SEM GTIN", cGtin)

	// Validações de configuração no Protheus
	If Empty(cToken)
		MsgStop("O parâmetro MV_XTOKIBP não está configurado no SIGACFG com o Token da empresa!", "IBPT - Configuração")
		Return Nil
	EndIf

	cCnpj   := StrTran(StrTran(StrTran(cCnpj, ".", ""), "/", ""), "-", "")
	cCodigo := StrTran(cCodigo, ".", "")

	If Empty(cCnpj) .Or. Len(cCnpj) < 14
		MsgStop("O CNPJ da empresa/filial atual (M0_CGC) está vazio ou inválido!", "IBPT - Configuração")
		Return Nil
	EndIf

	oRest := FWRest():New("https://apidoni.ibpt.org.br")

	If Upper(cTipo) == "P"
		cEndpoint := "/api/v1/produtos"
		cParamUrl := "token=" + cToken + ;
			"&cnpj=" + cCnpj + ;
			"&codigo=" + AllTrim(cCodigo) + ;
			"&uf=" + AllTrim(cUF) + ;
			"&ex=" + cValToChar(nEx) + ;
			"&descricao=" + EncodeUTF8(AllTrim(cDesc)) + ;
			"&unidadeMedida=" + EncodeUTF8(AllTrim(cUM)) + ;
			"&valor=" + cValToChar(nValor) + ;
			"&gtin=" + AllTrim(cGtin)
	Else
		cEndpoint := "/api/v1/servicos"
		cParamUrl := "token=" + cToken + ;
			"&cnpj=" + cCnpj + ;
			"&codigo=" + AllTrim(cCodigo) + ;
			"&uf=" + AllTrim(cUF) + ;
			"&descricao=" + EncodeUTF8(AllTrim(cDesc)) + ;
			"&unidadeMedida=" + EncodeUTF8(AllTrim(cUM)) + ;
			"&valor=" + cValToChar(nValor)
	EndIf

	oRest:SetPath(cEndpoint)
	oRest:SetGetParams(cParamUrl)

	AAdd(aHeader, "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
	AAdd(aHeader, "Accept: application/json")

	If oRest:Get(aHeader)
		cResponse := oRest:GetResult()

		If !Empty(cResponse)
			If oJsonParser:FromJson(cResponse) == Nil
				If ValType(oJsonParser) == "A" .And. Len(oJsonParser) > 0
					jRet := oJsonParser[1]
				Else
					jRet := oJsonParser
				EndIf
			Else
				ConOut("[IBPT] Erro ao processar JSON retornado: " + cResponse)
			EndIf
		EndIf
	Else
		MsgStop("Falha ao consultar API IBPT!" + CRLF + ;
			"HTTP Code: " + cValToChar(oRest:GetHTTPCode()) + CRLF + ;
			"Erro: " + oRest:GetLastError() + CRLF + ;
			"Resposta: " + oRest:GetResult(), "Diagnóstico API IBPT")
		ConOut("[IBPT ERROR] " + oRest:GetLastError() + " | Response: " + oRest:GetResult())
	EndIf

	FreeObj(oRest)
Return jRet
