use "ponytest"
use "collections"

// primitive _TestHint is EventHint
primitive _SomeTestEventError is EventError
  fun apply(): String => "except"
primitive _OtherTestEventError is EventError
  fun apply(): String => "except"

// TODO: _test_events - Test with all #alias refcap types
// TODO: _TestEventsPush? Its functionality tested through other event tests.
// TODO: _TestEventsEmitter? Its functionality tested through other event tests.
// TODO: _TestEventsMutable? Its functionality tested through mutate eventtests.

class _TestEmitter[T: Any #alias] is (Push[T] & Observer[T])
  let _emitter: Emitter[T] = BuildEvents.emitter[T]()
  var unsubscription_count: U32 = 0

  fun ref on_reaction(observer: Observer[T]): Subscription =>
    let self = this
    BuildSubscription.composite([
      _emitter.on_reaction(observer)
      BuildSubscription({ref () =>
        self.unsubscription_count = self.unsubscription_count + 1})
    ])

  fun ref react(value: T, hint: (EventHint | None) = None) =>
    _emitter.react(value, hint)
  fun ref except(x: EventError) => _emitter.except(x)
  fun ref unreact() => _emitter.unreact()
  fun ref get_observers(): SetIs[Observer[T]] =>
    _emitter.get_observers()
  fun _get_events_unreacted(): Bool => _emitter._get_events_unreacted()
  fun ref _set_events_unreacted(value: Bool) =>
    _emitter._set_events_unreacted(value)


class iso _TestEventsNever is UnitTest
  var unreacted: Bool = false

  fun name():String => "events/never"

  fun ref apply(h: TestHelper) =>
    let self = this
    let emitter = BuildEvents.never[None]()
    emitter.on_done({ref () => self.unreacted = true})
    h.assert_true(unreacted)


class iso _TestEventsImmediatelyUnreactToClosed is UnitTest
  var unreacted: Bool = false

  fun name():String => "events/immediately unreact to closed"

  fun ref apply(h: TestHelper) =>
    let self = this
    let emitter = BuildEvents.emitter[USize]()
    emitter.unreact()
    emitter.on_done({ref () => self.unreacted = true})
    h.assert_true(unreacted)


class iso _TestEventsOnReaction is UnitTest
  var event: (String | None) = None
  var event_error: (EventError | None) = None
  var unreacted: Bool = false

  fun name():String => "events/sinks/on_reaction"

  fun ref apply(h: TestHelper) =>
    let self = this
    let emitter = BuildEvents.emitter[String]()
    emitter.on_reaction(BuildObserver[String](
      where
        react' = {
          (s: String, hint: (EventHint | None) = None) => self.event = s
        },
        except' = {
          (x: EventError) => self.event_error = x
        },
        unreact' = {
          () => self.unreacted = true
        }
    ))

    emitter.react("ok")
    try h.assert_eq[String]("ok", event as String)
    else h.fail("react event not propogated") end
    try h.assert_is[None](None, event_error as None)
    else h.fail("except event without except") end
    h.assert_false(unreacted, "unreact event without unreact")

    emitter.except(_SomeTestEventError)
    try h.assert_eq[String]("ok", event as String)
    else h.fail("`event` should still be String") end
    try h.assert_is[_SomeTestEventError](
      _SomeTestEventError,
      event_error as _SomeTestEventError)
    else h.fail("except event not propogated") end
    h.assert_false(unreacted, "unreact event without unreact")

    emitter.unreact()
    try h.assert_eq[String]("ok", event as String)
    else h.fail("`event` should still be a String") end
    try h.assert_is[_SomeTestEventError](
      _SomeTestEventError,
      event_error as _SomeTestEventError)
    else h.fail("`event_error` should still be `_SomeTestEventError`") end
    h.assert_true(unreacted, "unreact event not propogated")

    emitter.react("nope")
    emitter.except(_OtherTestEventError)
    unreacted = false
    emitter.unreact()
    try h.assert_eq[String]("ok", event as String)
    else h.fail("`event` should still be a String") end
    try h.assert_is[_SomeTestEventError](
      _SomeTestEventError,
      event_error as _SomeTestEventError)
    else h.fail("`event_error` should still be `_SomeTestEventError`") end
    h.assert_false(unreacted, "unreact event propogated more than once")


class iso _TestEventsOnReactionUnsubscribe is UnitTest
  var event: (String | None) = None
  var event_error: (EventError | None) = None
  var unreacted: Bool = false

  fun name():String => "events/sinks/on_reaction/unsubscribe"

  fun ref apply(h: TestHelper) =>
    let self = this
    let emitter = BuildEvents.emitter[String]()
    let sub = emitter.on_reaction(BuildObserver[String](
      where
        react' = {
          (s: String, hint: (EventHint | None) = None) => self.event = s
        },
        except' = {
          (x: EventError) => self.event_error = x
        },
        unreact' = {
          () => self.unreacted = true
        }
    ))

    emitter.react("ok")
    try h.assert_eq[String]("ok", event as String)
    else h.fail("react event not propogated") end
    try h.assert_is[None](None, event_error as None)
    else h.fail("except event without except") end
    h.assert_false(unreacted, "unreact event without unreact")

    sub.unsubscribe()

    emitter.react("nope")
    try h.assert_eq[String]("ok", event as String)
    else h.fail("`event` should still be String") end
    try h.assert_is[None](None, event_error as None)
    else h.fail("except event without except") end
    h.assert_false(unreacted, "unreact event without unreact")


class iso _TestEventsOnEventOrDone is UnitTest
  var event: (String | None) = None
  var unreacted: Bool = false

  fun name():String => "events/sinks/on_event_or_done"

  fun ref apply(h: TestHelper) =>
    let self = this
    let emitter = BuildEvents.emitter[String]()
    emitter.on_event_or_done(
      where
        react_handler = {
          (s: String, hint: (EventHint | None) = None) => self.event = s
        },
        unreact_handler = {
          () => self.unreacted = true
        }
    )

    emitter.react("ok")
    try h.assert_eq[String]("ok", event as String)
    else h.fail("react event not propogated") end
    h.assert_false(unreacted, "unreact event without unreact")

    emitter.unreact()
    try h.assert_eq[String]("ok", event as String)
    else h.fail("`event` should still be a String") end
    h.assert_true(unreacted, "unreact event not propogated")


class iso _TestEventsOnEvent is UnitTest
  var event: (String | None) = None

  fun name():String => "events/sinks/on_event"

  fun ref apply(h: TestHelper) =>
    let self = this
    let emitter = BuildEvents.emitter[String]()
    let sub = emitter.on_event(
      where
        react_handler = {
          (s: String, hint: (EventHint | None) = None) => self.event = s
        }
    )

    emitter.react("ok")
    try h.assert_eq[String]("ok", event as String)
    else h.fail("react event not propogated") end

    sub.unsubscribe()

    emitter.react("other")
    try h.assert_eq[String]("ok", event as String)
    else h.fail("`event` should still be a String") end


class iso _TestEventsOnMatch is UnitTest
  fun name():String => "NI/events/sinks/on_match"
  fun ref apply(h: TestHelper) => h.fail("not implemented")


class iso _TestEventsOn is UnitTest
  var count: U32 = 0

  fun name():String => "events/sinks/on"

  fun ref apply(h: TestHelper) =>
    let self = this
    let emitter = BuildEvents.emitter[String]()
    let sub = emitter.on(
      where
        react_handler = {
          () => self.count = self.count + 1
        }
    )

    h.assert_eq[U32](0, count)
    emitter.react("first")
    h.assert_eq[U32](1, count)
    emitter.react("second")
    h.assert_eq[U32](2, count)
    sub.unsubscribe()
    emitter.react("ignored")
    h.assert_eq[U32](2, count)


class iso _TestEventsOnDone is UnitTest
  var unreacted: Bool = false

  fun name():String => "events/sinks/on_done"

  fun ref apply(h: TestHelper) =>
    let self = this
    let emitter = BuildEvents.emitter[String]()
    emitter.on_done(
      where
        unreact_handler = {
          () => self.unreacted = true
        }
    )

    h.assert_false(unreacted)
    emitter.react("event")
    h.assert_false(unreacted)
    emitter.unreact()
    h.assert_true(unreacted)


class iso _TestEventsOnDoneUnsubscribe is UnitTest
  var unreacted: Bool = false

  fun name():String => "events/sinks/on_done/unsubscribe"

  fun ref apply(h: TestHelper) =>
    let self = this
    let emitter = BuildEvents.emitter[String]()
    let sub = emitter.on_done(
      where
        unreact_handler = {
          () => self.unreacted = true
        }
    )

    h.assert_false(unreacted)
    emitter.react("event")
    h.assert_false(unreacted)
    sub.unsubscribe()
    emitter.unreact()
    h.assert_false(unreacted)


class iso _TestEventsOnExcept is UnitTest
  var error_found: Bool = false

  fun name():String => "events/sinks/on_except"

  fun ref apply(h: TestHelper) =>
    let self = this
    let emitter = BuildEvents.emitter[String]()
    emitter.on_except(
      where
        except_handler = {
          (e: EventError) =>
            match e
            | _SomeTestEventError => self.error_found = true
            end
        }
    )

    h.assert_false(error_found)
    emitter.except(_OtherTestEventError)
    h.assert_false(error_found)
    emitter.except(_SomeTestEventError)
    h.assert_true(error_found)


class iso _TestEventsAfter is UnitTest
  var seen: Bool = false

  fun name():String => "events/after/basic"

  fun ref apply(h: TestHelper) =>
    let self = this
    let emitter = BuildEvents.emitter[U32]()
    let start = BuildEvents.emitter[None]()
    let after = emitter.after[None](start)
    after.on({ref () => self.seen = true})

    // Test basic after behavior
    h.assert_false(seen)
    emitter.react(7)
    h.assert_false(seen)
    start.react(None)
    h.assert_false(seen)
    emitter.react(11)
    h.assert_true(seen)


class iso _TestEventsAfterUnreactsWithThis is UnitTest
  var unreacted: Bool = false

  fun name():String => "events/after/unreacts with this"

  fun ref apply(h: TestHelper) =>
    let self = this
    let emitter = BuildEvents.emitter[U32]()
    let start = BuildEvents.emitter[None]()
    let after = emitter.after[None](start)
    after.on_done({ref () => self.unreacted = true})

    // Ensure `after` unreacts when `emitter` unreacts
    h.assert_false(unreacted)
    emitter.unreact()
    h.assert_true(unreacted)


class iso _TestEventsAfterUnreactsWithThat is UnitTest
  var unreacted: Bool = false

  fun name():String => "events/after/unreacts with that"

  fun ref apply(h: TestHelper) =>
    let self = this
    let emitter = BuildEvents.emitter[U32]()
    let start = BuildEvents.emitter[None]()
    let after = emitter.after[None](start)
    after.on_done({ref () => self.unreacted = true})

    // Ensure `after` unreacts when `start` unreacts before producing
    h.assert_false(unreacted)
    start.unreact() // Unreact without producing
    h.assert_true(unreacted)


class iso _TestEventsAfterUnsubscribesThat is UnitTest
  fun name():String => "events/after/unsubscribes to that after it produces"

  fun ref apply(h: TestHelper) =>
    let emitter = BuildEvents.emitter[None]()
    let start: _TestEmitter[None] ref = _TestEmitter[None]
    let after = emitter.after[None](start)

    // At least one observer needed to propogate, hence call to `on`
    after.on({ref () => None})

    // Ensure unsubscribe from start after observing reaction
    h.assert_eq[U32](0, start.unsubscription_count)
    start.react(None)
    h.assert_eq[U32](1, start.unsubscription_count)


class iso _TestEventsBatch is UnitTest
  fun name():String => "NI/events/Batch"
  fun ref apply(h: TestHelper) => h.fail("not implemented")


class iso _TestEventsChanged is UnitTest
  fun name():String => "NI/events/Changed"
  fun ref apply(h: TestHelper) => h.fail("not implemented")


class iso _TestEventsCollect is UnitTest
  fun name():String => "NI/events/Collect"
  fun ref apply(h: TestHelper) => h.fail("not implemented")


class iso _TestEventsCollectHint is UnitTest
  fun name():String => "NI/events/CollectHint"
  fun ref apply(h: TestHelper) => h.fail("not implemented")


class iso _TestEventsConcatStreams is UnitTest
  fun name():String => "NI/events/ConcatStreams"
  fun ref apply(h: TestHelper) => h.fail("not implemented")


class iso _TestEventsConcat is UnitTest
  fun name():String => "NI/events/Concat"
  fun ref apply(h: TestHelper) => h.fail("not implemented")


class iso _TestEventsCount is UnitTest
  fun name():String => "NI/events/Count"
  fun ref apply(h: TestHelper) => h.fail("not implemented")


class iso _TestEventsDefer is UnitTest
  fun name():String => "NI/events/Defer"
  fun ref apply(h: TestHelper) => h.fail("not implemented")


class iso _TestEventsDone is UnitTest
  fun name():String => "NI/events/Done"
  fun ref apply(h: TestHelper) => h.fail("not implemented")


class iso _TestEventsDrop is UnitTest
  fun name():String => "NI/events/Drop"
  fun ref apply(h: TestHelper) => h.fail("not implemented")


class iso _TestEventsDropAfter is UnitTest
  fun name():String => "NI/events/DropAfter"
  fun ref apply(h: TestHelper) => h.fail("not implemented")


class iso _TestEventsDropWhile is UnitTest
  fun name():String => "NI/events/DropWhile"
  fun ref apply(h: TestHelper) => h.fail("not implemented")


class iso _TestEventsEach is UnitTest
  fun name():String => "NI/events/Each"
  fun ref apply(h: TestHelper) => h.fail("not implemented")


class iso _TestEventsFilter is UnitTest
  fun name():String => "NI/events/Filter"
  fun ref apply(h: TestHelper) => h.fail("not implemented")


class iso _TestEventsFirst is UnitTest
  fun name():String => "NI/events/First"
  fun ref apply(h: TestHelper) => h.fail("not implemented")


class iso _TestEventsGet is UnitTest
  fun name():String => "NI/events/Get"
  fun ref apply(h: TestHelper) => h.fail("not implemented")


class iso _TestEventsGroupBy is UnitTest
  fun name():String => "NI/events/GroupBy"
  fun ref apply(h: TestHelper) => h.fail("not implemented")


class iso _TestEventsIgnoreExceptions is UnitTest
  fun name():String => "NI/events/IgnoreExceptions"
  fun ref apply(h: TestHelper) => h.fail("not implemented")


class iso _TestEventsIncremental is UnitTest
  fun name():String => "NI/events/Incremental"
  fun ref apply(h: TestHelper) => h.fail("not implemented")


class iso _TestEventsLast is UnitTest
  fun name():String => "NI/events/Last"
  fun ref apply(h: TestHelper) => h.fail("not implemented")


/*
// Scala specific
class iso _TestEventsLiftTry is UnitTest
  fun name():String => "NI/events/LiftTry"
  fun ref apply(h: TestHelper) => h.fail("not implemented")
*/


class iso _TestEventsMap is UnitTest
  fun name():String => "NI/events/Map"
  fun ref apply(h: TestHelper) => h.fail("not implemented")


class iso _TestEventsMaterialize is UnitTest
  fun name():String => "NI/events/Materialize"
  fun ref apply(h: TestHelper) => h.fail("not implemented")


class iso _TestEventsMutate1 is UnitTest
  var length: USize = 0
  var log: Mutable[Array[String]] =
    BuildEvents.mutable[Array[String]](Array[String])

  fun name():String => "events/mutable/mutate1"

  fun ref apply(h: TestHelper) =>
    let self = this
    let emitter = BuildEvents.emitter[String]()
    emitter.mutate[Array[String]](
      where
        mutable = log,
        mutator = {ref (a: Array[String], e: String) =>
          a.push(e)
        }
    )
    log.on_event(
      where
        react_handler = {
          (a: Array[String], hint: (EventHint | None) = None) =>
            self.length = a.size()
        }
    )

    h.assert_eq[USize](0, length)
    emitter.react("one")
    h.assert_eq[USize](1, length)
    emitter.react("two")
    h.assert_eq[USize](2, length)
    h.assert_array_eq[String](
      ["one"; "two"],
      log.content
    )


class iso _TestEventsMutate2 is UnitTest
  fun name():String => "NI/events/mutable/mutate2"
  fun ref apply(h: TestHelper) => h.fail("not implemented")


class iso _TestEventsMutate3 is UnitTest
  fun name():String => "NI/events/mutable/mutate3"
  fun ref apply(h: TestHelper) => h.fail("not implemented")


class iso _TestEventsMux is UnitTest
  fun name():String => "NI/events/Mux"
  fun ref apply(h: TestHelper) => h.fail("not implemented")


class iso _TestEventsOnce is UnitTest
  fun name():String => "NI/events/Once"
  fun ref apply(h: TestHelper) => h.fail("not implemented")


class iso _TestEventsPartition is UnitTest
  fun name():String => "NI/events/Partition"
  fun ref apply(h: TestHelper) => h.fail("not implemented")


class iso _TestEventsPipe is UnitTest
  fun name():String => "NI/events/Pipe"
  fun ref apply(h: TestHelper) => h.fail("not implemented")


class iso _TestEventsPossibly is UnitTest
  fun name():String => "NI/events/Possibly"
  fun ref apply(h: TestHelper) => h.fail("not implemented")


class iso _TestEventsRecover is UnitTest
  fun name():String => "NI/events/Recover"
  fun ref apply(h: TestHelper) => h.fail("not implemented")


class iso _TestEventsReducePast is UnitTest
  fun name():String => "NI/events/ReducePast"
  fun ref apply(h: TestHelper) => h.fail("not implemented")


class iso _TestEventsRepeat is UnitTest
  fun name():String => "NI/events/Repeat"
  fun ref apply(h: TestHelper) => h.fail("not implemented")


class iso _TestEventsReverse is UnitTest
  fun name():String => "NI/events/Reverse"
  fun ref apply(h: TestHelper) => h.fail("not implemented")


class iso _TestEventsSample is UnitTest
  fun name():String => "NI/events/Sample"
  fun ref apply(h: TestHelper) => h.fail("not implemented")


class iso _TestEventsScanPast is UnitTest
  fun name():String => "NI/events/ScanPast"
  fun ref apply(h: TestHelper) => h.fail("not implemented")


class iso _TestEventsSliding is UnitTest
  fun name():String => "NI/events/Sliding"
  fun ref apply(h: TestHelper) => h.fail("not implemented")


class iso _TestEventsSync is UnitTest
  fun name():String => "NI/events/Sync"
  fun ref apply(h: TestHelper) => h.fail("not implemented")


class iso _TestEventsTail is UnitTest
  fun name():String => "NI/events/Tail"
  fun ref apply(h: TestHelper) => h.fail("not implemented")


class iso _TestEventsTake is UnitTest
  fun name():String => "NI/events/Take"
  fun ref apply(h: TestHelper) => h.fail("not implemented")


class iso _TestEventsTakeWhile is UnitTest
  fun name():String => "NI/events/TakeWhile"
  fun ref apply(h: TestHelper) => h.fail("not implemented")


class iso _TestEventsToColdSignal is UnitTest
  var last: USize = 0

  fun name():String => "events/to_cold_signal/basic"

  fun ref apply(h: TestHelper) =>
    let self = this
    let emitter = BuildEvents.emitter[USize]()
    let signal = emitter.to_cold_signal(1)
    // Signal should hold initial value.
    try h.assert_eq[USize](1, signal()?, "signal should hold initial value") end
    // Cold signal should not change without observers
    emitter.react(7)
    try h.assert_eq[USize](
      1, signal()?,
      "cold signal value should not change without observers")
    end
    // Cold signal should change and react with observers
    var sub = signal.on_event(
      where
        react_handler = {
          (value: USize, hint: (EventHint | None) = None) =>
            self.last = value
        }
    )
    emitter.react(11)
    try h.assert_eq[USize](
      11, signal()?,
      "cold signal with observers should change when its event stream reacts")
    end
    h.assert_eq[USize](11, last, "observer not reacted to signal change")
    // Cold signal should not change without observers
    sub.unsubscribe()
    emitter.react(17)
    try h.assert_eq[USize](
      11, signal()?,
      "cold signal value should not change without observers")
    end
    h.assert_eq[USize](11, last, "observer reacted after unsubscribe")
    // Cold signal should change and react with observers again
    sub = signal.on_event(
      where
        react_handler = {
          (value: USize, hint: (EventHint | None) = None) =>
            self.last = value
        }
    )
    emitter.react(19)
    try h.assert_eq[USize](
      19, signal()?,
      "cold signal with observers should change when its event stream reacts")
    end
    h.assert_eq[USize](19, last, "observer not reacted to signal change")


class iso _TestEventsToColdSignalUnsubscribesWithNoObservers is UnitTest
  var last: USize = 0

  fun name():String => "events/to_cold_signal/unsubscribes with no observers"

  fun ref apply(h: TestHelper) =>
    let self = this
    let emitter: _TestEmitter[USize] ref = _TestEmitter[USize]
    let signal = emitter.to_cold_signal(7)
    // Cold signal should unsubscribe when all observers unsubscribe
    let sub1 = signal.on_event(
      where
        react_handler = {
          (value: USize, hint: (EventHint | None) = None) =>
            self.last = value
        }
    )
    emitter.react(11)
    h.assert_eq[USize](11, last, "observer not reacted to signal change")
    sub1.unsubscribe()
    h.assert_eq[U32](1, emitter.unsubscription_count)
    // Cold signal should unsubscribe when ONLY all observers unsubscribe
    let sub2 = signal.on_event(
      where
        react_handler = {
          (value: USize, hint: (EventHint | None) = None) =>
            self.last = value
        }
    )
    let sub3 = signal.on_event(
      where
        react_handler = {
          (value: USize, hint: (EventHint | None) = None) =>
            self.last = value
        }
    )
    sub2.unsubscribe()
    h.assert_eq[U32](1, emitter.unsubscription_count)
    sub3.unsubscribe()
    h.assert_eq[U32](2, emitter.unsubscription_count)


class iso _TestEventsToColdSignalUnreactsWhenDone is UnitTest
  var done: Bool = false

  fun name():String => "events/to_cold_signal/unreacts when done"

  fun ref apply(h: TestHelper) =>
    let self = this
    let emitter: _TestEmitter[USize] ref = _TestEmitter[USize]
    let signal = emitter.to_cold_signal(7)
    // Cold signal should unsubscribe when unreacted.
    h.assert_false(emitter.has_subscriptions())
    signal.on({() => None})
    h.assert_true(emitter.has_subscriptions())
    emitter.unreact()
    h.assert_false(emitter.has_subscriptions())
    // Cold signal should auto-unreact new observers when it has unreacted.
    signal.on_done(
      where
        unreact_handler = {
          () => self.done = true
        }
    )
    h.assert_true(done)
    h.assert_false(emitter.has_subscriptions())


class iso _TestEventsToColdSignalUsedWithZipRemovesSubscriptions is UnitTest
  fun name():String =>
    "NI/events/to_cold_signal/used with zip removes subscriptions"
  fun ref apply(h: TestHelper) => h.fail("not implemented")


class iso _TestEventsToDoneSignal is UnitTest
  fun name():String => "NI/events/to_done_signal"
  fun ref apply(h: TestHelper) => h.fail("not implemented")


class iso _TestEventsToEagerSignal is UnitTest
  var reacted: Bool = false

  fun name():String => "events/to_eager_signal"

  fun ref apply(h: TestHelper) =>
    let self = this
    let emitter = BuildEvents.emitter[USize]()
    let signal = emitter.to_eager_signal()
    // Signal should not react new observers when empty.
    h.assert_true(signal.is_empty(), "signal should be empty")
    var sub = signal.on(
      where
        react_handler = {
          () => self.reacted = true
        }
    )
    h.assert_false(
      reacted, "eager signal should not react new observer when empty")
    sub.unsubscribe()
    // Signal should cache value on reaction.
    emitter.react(7)
    try h.assert_eq[USize](7, signal()?)
    else h.fail("signal should not be empty") end
    // Signal should react new observers when caching value.
    sub = signal.on(
      where
        react_handler = {
          () => self.reacted = true
        }
    )
    h.assert_true(
      reacted, "eager signal should react new observer when caching value")
    // Signal should hold last cached value after unsubscribe.
    signal.unsubscribe()
    emitter.react(11) // ..and ignore further event propogation.
    try h.assert_eq[USize](
      7, signal()?,
      "signal's value changed after unsubscribe")
    else h.fail("signal should not be empty") end


class iso _TestEventsToEmptySignal is UnitTest
  fun name():String => "events/to_empty_signal"

  fun ref apply(h: TestHelper) =>
    let emitter = BuildEvents.emitter[USize]()
    let signal = emitter.to_empty_signal()
    // Signal should error with empty value.
    try
      signal()?
      h.fail("signal should error when accessing empty value")
    else None end
    // Signal should cache value on reaction.
    emitter.react(7)
    try h.assert_eq[USize](7, signal()?)
    else h.fail("signal should not be empty") end
    // Signal should hold last cached value after unsubscribe.
    signal.unsubscribe()
    emitter.react(11) // ..and ignore further event propogation.
    try h.assert_eq[USize](
      7, signal()?,
      "signal's value changed after unsubscribe")
    else h.fail("signal should not be empty") end


class iso _TestEventsToEventBuffer is UnitTest
  fun name():String => "NI/events/ToEventBuffer"
  fun ref apply(h: TestHelper) => h.fail("not implemented")


class iso _TestEventsToIVar is UnitTest
  fun name():String => "NI/events/ToIVar"
  fun ref apply(h: TestHelper) => h.fail("not implemented")


class iso _TestEventsToRCell is UnitTest
  fun name():String => "NI/events/ToRCell"
  fun ref apply(h: TestHelper) => h.fail("not implemented")


class iso _TestEventsToSignal is UnitTest
  fun name():String => "events/to_signal/basic"

  fun ref apply(h: TestHelper) =>
    let emitter = BuildEvents.emitter[USize]()
    let signal = emitter.to_signal(1)
    // Signal should hold initial value.
    try h.assert_eq[USize](1, signal()?)
    else h.fail("signal should not be empty") end
    // Signal should cache value on reaction.
    emitter.react(7)
    try h.assert_eq[USize](7, signal()?)
    else h.fail("signal should not be empty") end
    // Signal should hold last cached value after unsubscribe.
    signal.unsubscribe()
    emitter.react(11) // ..and ignore further event propogation.
    try h.assert_eq[USize](
      7, signal()?,
      "signal's value changed after unsubscribe")
    else h.fail("signal should not be empty") end


class iso _TestEventsToSignalUnreactsWhenDone is UnitTest
  var unreacted: Bool = false

  fun name():String => "events/to_signal/unreacts when done"

  fun ref apply(h: TestHelper) =>
    let self = this
    let emitter: _TestEmitter[USize] ref = _TestEmitter[USize]
    let signal = emitter.to_signal(7)
    emitter.unreact()
    signal.on_done(
      where
        unreact_handler = {
          () => self.unreacted = true
        }
    )
    h.assert_true(unreacted)
    h.assert_false(emitter.has_subscriptions())


class iso _TestEventsUnionStreams is UnitTest
  fun name():String => "NI/events/UnionStreams"
  fun ref apply(h: TestHelper) => h.fail("not implemented")


class iso _TestEventsUnion is UnitTest
  fun name():String => "NI/events/Union"
  fun ref apply(h: TestHelper) => h.fail("not implemented")


/*
// Scala specific
class iso _TestEventsUnliftTry is UnitTest
  fun name():String => "NI/events/UnliftTry"
  fun ref apply(h: TestHelper) => h.fail("not implemented")
*/


class iso _TestEventsUnreacted is UnitTest
  fun name():String => "NI/events/Unreacted"
  fun ref apply(h: TestHelper) => h.fail("not implemented")


class iso _TestEventsUntil is UnitTest
  fun name():String => "NI/events/Until"
  fun ref apply(h: TestHelper) => h.fail("not implemented")


class iso _TestEventsZipHint is UnitTest
  fun name():String => "NI/events/ZipHint"
  fun ref apply(h: TestHelper) => h.fail("not implemented")
