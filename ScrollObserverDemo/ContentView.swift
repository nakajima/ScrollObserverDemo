//
//  ContentView.swift
//  ScrollObserverDemo
//
//  Created by Pat Nakajima on 4/22/24.
//

import SwiftUI
import AsyncAlgorithms

// Provides a binding for the scrollPosition(id:) modifier to write to
// and an async stream with debounced updates.
//
// I found that just using @State in the view wasn't great for scroll performance
// so ended up doing this.
@MainActor final class ScrollObserver<Element: Equatable & Sendable> {
	var _stream: AsyncDebounceSequence<AsyncStream<Element>, ContinuousClock>?
	var continuation: AsyncStream<Element>.Continuation?

	var debounce: Duration
	var currentValue: Element?

	init(debounce: Duration) {
		self.debounce = debounce
	}

	func stream() -> AsyncDebounceSequence<AsyncStream<Element>, ContinuousClock> {
		if let continuation {
			continuation.finish()
		}

		let (stream, continuation) = AsyncStream<Element>.makeStream(bufferingPolicy: .bufferingNewest(1))
		let debounced = stream.debounce(for: debounce)
		_stream = debounced
		self.continuation = continuation

		return debounced
	}

	lazy var position = Binding<Element?>(
		get: {
			nil
		},
		set: { newValue in
			guard let newValue else { return }

			self.currentValue = newValue
			self.continuation?.yield(newValue)
		}
	)
}

struct ContentView: View {
	let rowCount = 1000

	// How wide should the progress bar be (out of 1.0)
	@State private var progress = 0.0

	// Something for the scrollPosition modifier to write to
	let scrollObserver: ScrollObserver<Int>

	@MainActor init() {
		self.scrollObserver = ScrollObserver(debounce: .seconds(0.4))
	}

	var body: some View {
		VStack(spacing: 0) {
			// For finding the width of the screen
			GeometryReader { geo in
				ZStack(alignment: .leading) {
					// Placeholder
					Rectangle()
						.fill(.tertiary)

					// Progress bar
					Rectangle()
						.fill(Color.accentColor)
						.frame(width: geo.size.width * progress)
						.animation(.bouncy, value: progress)
				}
			}
			.frame(height: 2)

			// Where the content goes
			ScrollView {
				LazyVStack {
					ForEach(0..<rowCount, id: \.self) { i in
						Text("Line \(i)")
					}
				}
				.scrollTargetLayout()
			}
			// The scrollPosition writes to the scroll observer but never reads
			// from it.
			.scrollPosition(id: scrollObserver.position)
			.task {
				// We get updates on the scroll position from here
				for await newPosition in scrollObserver.stream() {
					self.progress = Double(newPosition) / Double(rowCount)
				}
			}
		}
	}
}

#Preview {
    ContentView()
}
