class_name CompleteStep
extends StoryStep
## The scene's completion boundary: the last step of every scene. The scene Resource's
## `completion` says what must be true here; the runner then commits the scene (RD-05).


func kind() -> String:
	return "complete"
