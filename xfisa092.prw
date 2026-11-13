#Include "Totvs.ch"
#Include "FWMVCDef.ch"

/*/{Protheus.doc} XFISA092
    Chamada customizada da FISA092 com Menu estendido via MenuDef
    @type Function
    @author Seu Nome
/*/
User Function XFISA092()
    Local oBrw := FWMBrowse():New()

    If AliasIndic("CLK")
        oBrw:SetAlias("CLK")
        oBrw:SetMenuDef('XFISA092')
        oBrw:SetDescription("Cadastro da Tabela IBPT - API")
        oBrw:Activate()
    Else
        Help("", 1, "Help", "Help", "Tabela CLK não cadastrada no sistema!", 1, 0)
    EndIf
Return

/*/{Protheus.doc} MenuDef
    MenuDef customizado com as opções padrão + botões da API IBPT
/*/
Static Function MenuDef()
    Local aRotina := {}

    ADD OPTION aRotina TITLE 'Visualizar'                   ACTION 'VIEWDEF.FISA092' OPERATION 2 ACCESS 0
    ADD OPTION aRotina TITLE 'Incluir'                      ACTION 'VIEWDEF.FISA092' OPERATION 3 ACCESS 0
    ADD OPTION aRotina TITLE 'Alterar'                      ACTION 'VIEWDEF.FISA092' OPERATION 4 ACCESS 0
    ADD OPTION aRotina TITLE 'Excluir'                      ACTION 'VIEWDEF.FISA092' OPERATION 5 ACCESS 0
    ADD OPTION aRotina TITLE 'Importar CSV'                 ACTION 'ImpIBPT()'       OPERATION 3 ACCESS 0
    ADD OPTION aRotina TITLE 'Atualizar Linha (API IBPT)'   ACTION 'U_F092Lin()'     OPERATION 4 ACCESS 0
    ADD OPTION aRotina TITLE 'Sincronizar Todos NCMs (API)' ACTION 'U_F092All()'     OPERATION 4 ACCESS 0

Return aRotina
