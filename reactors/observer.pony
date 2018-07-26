
trait Observer[T: Any #read]
  """
  An observer of values of type T produced by an event stream Events[T], or a
  signal indicating there will be no more events.
  """

  fun ref react(value: T, hint: (EventHint | None) = None) =>
    """
    Called by an event stream when an event 'value' is produced. `hint` may be
    provided as an extra value produced at the descretion of the event source.
    """
    None

  fun ref except(x: EventError) =>
    """
    Called by the event stream when there wasAny an error producing an event value.
    """
    None
  
  fun ref unreact() =>
    """
    Called by an event stream when there will be no more events produced.
    """
    None


primitive BuildObserver[T: Any #read]
  """ Observer Builder  """
  
  fun apply(
    react': {(T, (EventHint | None))},
    except': {(EventError)},
    unreact': {ref ()})
    : Observer[T]
  =>
    """
    Create and return an observer using the specified handlers.
    """
    object is Observer[T]
      fun react(value: T, hint: (EventHint | None) = None) =>
        react'(value, hint)
      fun except(x: EventError) => except'(x)
      fun ref unreact() => unreact'()
    end

  fun of_react_and_unreact(
    react': {(T, (EventHint | None))},
    unreact': {ref ()})
    : Observer[T]
  =>
    """
    Create and return an observer using the specified `react` and `unreact`
    handlers. `except` events are ignored.
    """
    object is Observer[T]
      fun react(value: T, hint: (EventHint | None) = None) =>
        react'(value, hint)
      fun ref unreact() => unreact'()
    end

  fun of_react(react': {(T, (EventHint | None))}): Observer[T] =>
    """
    Create and return an observer using the specified `react` handler.
    `except` and `unreact` events are ignored.
    """
    object is Observer[T]
      fun react(value: T, hint: (EventHint | None) = None) =>
        react'(value, hint)
    end

  fun of_react_without_regards(react': {()}): Observer[T] =>
    """
    Create and return an observer using the specified `react` handler, which
    disregards the value of the event. `except` and `unreact` events are
    ignored.
    """
    object is Observer[T]
      fun react(value: T, hint: (EventHint | None) = None) => react'()
    end

  fun of_unreact(unreact': {ref ()}): Observer[T] =>
    """
    Create and return an observer using the specified `unreact` handler.
    `react` and `except` events are ignored.
    """
    object is Observer[T]
      fun ref unreact() => unreact'()
    end

  fun of_except(except': {(EventError)}): Observer[T] =>
    """
    Create and return an observer using the specified `except` handler.
    `react` and `unreact` events are ignored.
    """
    object is Observer[T]
      fun except(x: EventError) => except'(x)
    end

  // TODO: BuildObserver.that_mutates docstring
  fun that_mutates[M: Any ref](
    mutable': Mutable[M],
    mutator': {ref (M, T)}) // TODO: mutator need not be ref?
    : Observer[T]
  =>
    """"""
    object is Observer[T]
      let mutation: {ref (T)} = mutator'~apply(mutable'.content)
      fun ref react(value: T, hint: (EventHint | None) = None) =>
        mutation(value)
        mutable'.react_all(mutable'.content, None)
      fun ref except(x: EventError) => mutable'.except_all(x)
    end
