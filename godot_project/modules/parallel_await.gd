class_name ParallelAwait
## Wrapper to concurrently await multiple awaitables


## Running task representation
class Task:

	## Emitted once all done
	signal done

	## Set once complete
	var complete: bool = false

	func _wrapper(callable: Callable, params: Array) -> void:
		await callable.callv(params)
		self.done.emit()
		self.complete = true

	func _init(callable: Callable, params: Array) -> void:
		@warning_ignore("missing_await")
		self._wrapper(callable, params)


static func async_join(
	callable_param_pairs: Array[Array]
) -> void:

	var tasks: Array[Task]

	for pair: Array in callable_param_pairs:
		tasks.append(
			Task.new(
				pair[0] as Callable,
				pair[1] as Array,
			)
		)

	for task in tasks:
		if not task.complete:
			await task.done
