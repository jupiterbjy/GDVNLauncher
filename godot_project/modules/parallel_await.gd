class_name ParallelAwait
## Wrapper to concurrently await multiple awaitables


## Running task representation
class Task:

	## Emitted once all done
	signal done

	## Set once complete
	var complete: bool = false
	
	var return_val: Variant = null

	func _wrapper(callable: Callable, params: Array) -> void:
		self.return_val = await callable.callv(params)
		self.done.emit()
		self.complete = true

	func _init(callable: Callable, params: Array) -> void:
		@warning_ignore("missing_await")
		self._wrapper.call(callable, params)


static func async_join(
	callable_param_pairs: Array[Array]
) -> Array[Variant]:

	var tasks: Array[Task]
	var results: Array[Variant]

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
		
		results.append(task.return_val)
	
	return results
