#include "protheus.ch"

/*/{Protheus.doc} MA092BUT
    Ponto de Entrada da rotina FISA092 para adicionar botões no menu "Outras Ações"
/*/
User Function MA092BUT()
	Local aBotoes := {}

	// Permite consultar a linha selecionada ou disparar a carga em lote dos produtos/serviços
	AAdd(aBotoes, {"Atualizar Linha (API IBPT)", {|| U_F092Lin()}, 0, 4})
	AAdd(aBotoes, {"Sincronizar Todos NCMs (API)", {|| U_F092All()}, 0, 4})

Return aBotoes
