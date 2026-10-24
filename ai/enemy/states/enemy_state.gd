class_name EnemyState
extends State
## Vihollisen tilojen kantaluokka. Antaa tyypitetyn pääsyn ohjaimeen ja havainnointiin.

var enemy: EnemyController:
	get:
		return owner as EnemyController

var perception: EnemyPerception:
	get:
		return enemy.perception if enemy else null
