import Foundation
import SwiftUI

// MARK: - Interactive Symbol

struct InteractiveSymbol: Identifiable {
    let id: String
    let displayName: String
    let kind: SwiftUISymbolKind
    let examples: [SwiftUIExample]

    static func match(for symbol: IndexedSwiftSymbol) -> InteractiveSymbol? {
        let examples = SwiftUIExampleCatalog.examples(for: symbol)
        guard !examples.isEmpty else { return nil }

        return InteractiveSymbol(
            id: symbol.stableID,
            displayName: symbol.name,
            kind: symbol.kind,
            examples: examples
        )
    }
}

// MARK: - Example Model

struct SwiftUIExample: Identifiable {
    let id: String
    let title: String
    let summary: String
    let match: SymbolExampleMatch
    let defaultValues: ExampleValues

    private let previewBuilder: (ExampleValues) -> AnyView
    private let controlsBuilder: (Binding<ExampleValues>) -> AnyView
    private let codeBuilder: (ExampleValues) -> String

    init<Preview: View, Controls: View>(
        id: String,
        title: String,
        summary: String = "",
        match: SymbolExampleMatch,
        defaultValues: ExampleValues = ExampleValues(),
        @ViewBuilder preview: @escaping (ExampleValues) -> Preview,
        @ViewBuilder controls: @escaping (Binding<ExampleValues>) -> Controls,
        code: @escaping (ExampleValues) -> String
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.match = match
        self.defaultValues = defaultValues
        self.previewBuilder = { AnyView(preview($0)) }
        self.controlsBuilder = { AnyView(controls($0)) }
        self.codeBuilder = code
    }

    func matches(_ symbol: IndexedSwiftSymbol) -> Bool {
        match.matches(kind: symbol.kind, symbolName: symbol.name)
    }

    func matches(kind: SwiftUISymbolKind, symbolName: String) -> Bool {
        match.matches(kind: kind, symbolName: symbolName)
    }

    func preview(values: ExampleValues) -> AnyView {
        previewBuilder(values)
    }

    func controls(values: Binding<ExampleValues>) -> AnyView {
        controlsBuilder(values)
    }

    func code(values: ExampleValues) -> String {
        codeBuilder(values)
    }
}

struct SymbolExampleMatch {
    let kind: SwiftUISymbolKind
    private let exactNames: Set<String>
    private let prefixes: [String]
    private let containsValues: [String]
    private let excludedContainsValues: [String]

    init(
        kind: SwiftUISymbolKind,
        names: [String] = [],
        prefixes: [String] = [],
        contains: [String] = [],
        excludingContains excludedContains: [String] = []
    ) {
        self.kind = kind
        self.exactNames = Set(names.map(Self.normalized))
        self.prefixes = prefixes.map(Self.normalized)
        self.containsValues = contains.map(Self.normalized)
        self.excludedContainsValues = excludedContains.map(Self.normalized)
    }

    func matches(kind symbolKind: SwiftUISymbolKind, symbolName: String) -> Bool {
        guard symbolKind == kind else { return false }

        let normalizedName = Self.normalized(symbolName)
        if excludedContainsValues.contains(where: normalizedName.contains) {
            return false
        }

        if exactNames.contains(normalizedName) {
            return true
        }

        if prefixes.contains(where: normalizedName.hasPrefix) {
            return true
        }

        return containsValues.contains(where: normalizedName.contains)
    }

    private static func normalized(_ value: String) -> String {
        value
            .lowercased()
            .filter { !$0.isWhitespace }
    }
}

// MARK: - Playground State

struct PlaygroundState: Equatable {
    var selectedExampleID: String?
    var valuesByExampleID: [String: ExampleValues] = [:]

    mutating func prepare(for symbol: InteractiveSymbol) {
        if
            let selectedExampleID,
            symbol.examples.contains(where: { $0.id == selectedExampleID })
        {
            if let selectedExample = symbol.examples.first(where: { $0.id == selectedExampleID }) {
                ensureDefaultValues(for: selectedExample)
            }
            return
        }

        selectedExampleID = symbol.examples.first?.id
        if let selectedExample = symbol.examples.first {
            ensureDefaultValues(for: selectedExample)
        }
    }

    mutating func reset(for symbol: InteractiveSymbol) {
        selectedExampleID = symbol.examples.first?.id
        valuesByExampleID = Dictionary(
            uniqueKeysWithValues: symbol.examples.map { ($0.id, $0.defaultValues) }
        )
    }

    mutating func ensureDefaultValues(for example: SwiftUIExample) {
        if valuesByExampleID[example.id] == nil {
            valuesByExampleID[example.id] = example.defaultValues
        }
    }

    mutating func reset(_ example: SwiftUIExample) {
        valuesByExampleID[example.id] = example.defaultValues
    }

    mutating func selectExample(id: String, for symbol: InteractiveSymbol) {
        guard let example = symbol.examples.first(where: { $0.id == id }) else {
            return
        }

        selectedExampleID = example.id
        ensureDefaultValues(for: example)
    }

    func selectedExample(for symbol: InteractiveSymbol) -> SwiftUIExample? {
        symbol.examples.first { $0.id == selectedExampleID } ?? symbol.examples.first
    }

    func values(for example: SwiftUIExample) -> ExampleValues {
        valuesByExampleID[example.id] ?? example.defaultValues
    }
}

struct ExampleValues: Equatable {
    var doubles: [String: Double] = [:]
    var ints: [String: Int] = [:]
    var bools: [String: Bool] = [:]
    var strings: [String: String] = [:]
    var colors: [String: ExampleColor] = [:]

    func double(_ key: String, default defaultValue: Double = 0) -> Double {
        doubles[key] ?? defaultValue
    }

    func cgFloat(_ key: String, default defaultValue: CGFloat = 0) -> CGFloat {
        CGFloat(double(key, default: Double(defaultValue)))
    }

    func int(_ key: String, default defaultValue: Int = 0) -> Int {
        ints[key] ?? defaultValue
    }

    func bool(_ key: String, default defaultValue: Bool = false) -> Bool {
        bools[key] ?? defaultValue
    }

    func string(_ key: String, default defaultValue: String = "") -> String {
        strings[key] ?? defaultValue
    }

    func color(_ key: String, default defaultValue: ExampleColor = .blue) -> ExampleColor {
        colors[key] ?? defaultValue
    }
}

extension Binding where Value == ExampleValues {
    func cgFloat(_ key: String, default defaultValue: CGFloat = 0) -> Binding<CGFloat> {
        Binding<CGFloat>(
            get: { wrappedValue.cgFloat(key, default: defaultValue) },
            set: { newValue in
                var values = wrappedValue
                values.doubles[key] = Double(newValue)
                wrappedValue = values
            }
        )
    }

    func int(_ key: String, default defaultValue: Int = 0) -> Binding<Int> {
        Binding<Int>(
            get: { wrappedValue.int(key, default: defaultValue) },
            set: { newValue in
                var values = wrappedValue
                values.ints[key] = newValue
                wrappedValue = values
            }
        )
    }

    func bool(_ key: String, default defaultValue: Bool = false) -> Binding<Bool> {
        Binding<Bool>(
            get: { wrappedValue.bool(key, default: defaultValue) },
            set: { newValue in
                var values = wrappedValue
                values.bools[key] = newValue
                wrappedValue = values
            }
        )
    }

    func string(_ key: String, default defaultValue: String = "") -> Binding<String> {
        Binding<String>(
            get: { wrappedValue.string(key, default: defaultValue) },
            set: { newValue in
                var values = wrappedValue
                values.strings[key] = newValue
                wrappedValue = values
            }
        )
    }

    func color(_ key: String, default defaultValue: ExampleColor = .blue) -> Binding<ExampleColor> {
        Binding<ExampleColor>(
            get: { wrappedValue.color(key, default: defaultValue) },
            set: { newValue in
                var values = wrappedValue
                values.colors[key] = newValue
                wrappedValue = values
            }
        )
    }
}

// MARK: - Catalog

enum SwiftUIExampleCatalog {
    static let examples: [SwiftUIExample] = modifierExamples + viewExamples

    static func examples(for symbol: IndexedSwiftSymbol) -> [SwiftUIExample] {
        examples.filter { $0.matches(symbol) }
    }

    static func examples(kind: SwiftUISymbolKind, symbolName: String) -> [SwiftUIExample] {
        examples.filter { $0.matches(kind: kind, symbolName: symbolName) }
    }
}

private extension SwiftUIExampleCatalog {
    static let modifierExamples: [SwiftUIExample] = [
        SwiftUIExample(
            id: "modifier.padding.basic",
            title: "Adjustable Padding",
            summary: "Changes the space around a view.",
            match: SymbolExampleMatch(kind: .modifier, prefixes: ["padding"]),
            defaultValues: ExampleValues(doubles: ["padding": 16]),
            preview: { values in
                let padding = values.cgFloat("padding", default: 16)
                Text("Hello, SwiftUI")
                    .font(.headline)
                    .padding(padding)
                    .background(.blue.opacity(0.14), in: .rect(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(.blue.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [5]))
                    }
            },
            controls: { values in
                LabeledSlider(label: "Padding", value: values.cgFloat("padding", default: 16), range: 0...60)
            },
            code: { values in
                """
                Text("Hello, SwiftUI")
                    .padding(\(ExampleFormat.number(values.cgFloat("padding", default: 16))))
                """
            }
        ),
        SwiftUIExample(
            id: "modifier.opacity.basic",
            title: "Opacity",
            summary: "Fades the view while keeping its layout.",
            match: SymbolExampleMatch(kind: .modifier, prefixes: ["opacity"]),
            defaultValues: ExampleValues(doubles: ["opacity": 1]),
            preview: { values in
                Text("Hello, SwiftUI")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding()
                    .background(.blue.gradient, in: .rect(cornerRadius: 8))
                    .opacity(values.double("opacity", default: 1))
            },
            controls: { values in
                LabeledSlider(
                    label: "Opacity",
                    value: values.cgFloat("opacity", default: 1),
                    range: 0...1,
                    unit: "",
                    step: 0.05
                )
            },
            code: { values in
                """
                Text("Hello, SwiftUI")
                    .opacity(\(ExampleFormat.number(values.double("opacity", default: 1))))
                """
            }
        ),
        SwiftUIExample(
            id: "modifier.blur.basic",
            title: "Blur Radius",
            summary: "Applies a Gaussian blur to the view.",
            match: SymbolExampleMatch(kind: .modifier, prefixes: ["blur"]),
            defaultValues: ExampleValues(doubles: ["radius": 0]),
            preview: { values in
                Text("Hello, SwiftUI")
                    .font(.title2.weight(.semibold))
                    .blur(radius: values.cgFloat("radius"))
            },
            controls: { values in
                LabeledSlider(label: "Radius", value: values.cgFloat("radius"), range: 0...20)
            },
            code: { values in
                """
                Text("Hello, SwiftUI")
                    .blur(radius: \(ExampleFormat.number(values.cgFloat("radius"))))
                """
            }
        ),
        SwiftUIExample(
            id: "modifier.shadow.basic",
            title: "Shadow",
            summary: "Adds depth with radius and offset controls.",
            match: SymbolExampleMatch(kind: .modifier, prefixes: ["shadow"]),
            defaultValues: ExampleValues(
                doubles: ["radius": 8, "x": 0, "y": 5],
                colors: ["color": .gray]
            ),
            preview: { values in
                Text("Hello, SwiftUI")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding()
                    .background(.blue.gradient, in: .rect(cornerRadius: 8))
                    .shadow(
                        color: values.color("color", default: .gray).color,
                        radius: values.cgFloat("radius", default: 8),
                        x: values.cgFloat("x"),
                        y: values.cgFloat("y", default: 5)
                    )
            },
            controls: { values in
                ExampleColorPicker(label: "Color", selection: values.color("color", default: .gray))
                LabeledSlider(label: "Radius", value: values.cgFloat("radius", default: 8), range: 0...30)
                LabeledSlider(label: "X Offset", value: values.cgFloat("x"), range: -30...30)
                LabeledSlider(label: "Y Offset", value: values.cgFloat("y", default: 5), range: -30...30)
            },
            code: { values in
                """
                Text("Hello, SwiftUI")
                    .shadow(
                        color: \(values.color("color", default: .gray).code),
                        radius: \(ExampleFormat.number(values.cgFloat("radius", default: 8))),
                        x: \(ExampleFormat.number(values.cgFloat("x"))),
                        y: \(ExampleFormat.number(values.cgFloat("y", default: 5)))
                    )
                """
            }
        ),
        SwiftUIExample(
            id: "modifier.clipshape.rounded",
            title: "Rounded Clipping",
            summary: "Clips a background to a rounded rectangle.",
            match: SymbolExampleMatch(kind: .modifier, contains: ["cornerRadius", "clipShape"]),
            defaultValues: ExampleValues(doubles: ["cornerRadius": 12]),
            preview: { values in
                Text("Hello, SwiftUI")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding()
                    .background(.blue.gradient)
                    .clipShape(.rect(cornerRadius: values.cgFloat("cornerRadius", default: 12)))
            },
            controls: { values in
                LabeledSlider(
                    label: "Corner Radius",
                    value: values.cgFloat("cornerRadius", default: 12),
                    range: 0...50
                )
            },
            code: { values in
                """
                Text("Hello, SwiftUI")
                    .padding()
                    .background(.blue)
                    .clipShape(.rect(cornerRadius: \(ExampleFormat.number(values.cgFloat("cornerRadius", default: 12)))))
                """
            }
        ),
        SwiftUIExample(
            id: "modifier.rotation.basic",
            title: "Rotation",
            summary: "Rotates a view around its center.",
            match: SymbolExampleMatch(kind: .modifier, contains: ["rotation"]),
            defaultValues: ExampleValues(doubles: ["degrees": 0]),
            preview: { values in
                Text("Hello, SwiftUI")
                    .font(.headline)
                    .padding()
                    .background(.blue.opacity(0.16), in: .rect(cornerRadius: 8))
                    .rotationEffect(.degrees(values.double("degrees")))
            },
            controls: { values in
                LabeledSlider(label: "Degrees", value: values.cgFloat("degrees"), range: -180...180, unit: "deg")
            },
            code: { values in
                """
                Text("Hello, SwiftUI")
                    .rotationEffect(.degrees(\(ExampleFormat.number(values.double("degrees")))))
                """
            }
        ),
        SwiftUIExample(
            id: "modifier.scale.basic",
            title: "Scale",
            summary: "Scales the rendered view without changing its original layout proposal.",
            match: SymbolExampleMatch(kind: .modifier, prefixes: ["scaleEffect"], contains: ["scale"]),
            defaultValues: ExampleValues(doubles: ["scale": 1]),
            preview: { values in
                Text("Hello, SwiftUI")
                    .font(.headline)
                    .padding()
                    .background(.blue.opacity(0.16), in: .rect(cornerRadius: 8))
                    .scaleEffect(values.double("scale", default: 1))
            },
            controls: { values in
                LabeledSlider(
                    label: "Scale",
                    value: values.cgFloat("scale", default: 1),
                    range: 0.1...3,
                    unit: "x",
                    step: 0.1
                )
            },
            code: { values in
                """
                Text("Hello, SwiftUI")
                    .scaleEffect(\(ExampleFormat.number(values.double("scale", default: 1))))
                """
            }
        ),
        SwiftUIExample(
            id: "modifier.offset.basic",
            title: "Offset",
            summary: "Moves the rendered view by x and y points.",
            match: SymbolExampleMatch(kind: .modifier, prefixes: ["offset"]),
            defaultValues: ExampleValues(doubles: ["x": 0, "y": 0]),
            preview: { values in
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(.secondary.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [5]))
                        .frame(width: 150, height: 54)
                    Text("Hello, SwiftUI")
                        .font(.headline)
                        .padding()
                        .background(.blue.opacity(0.16), in: .rect(cornerRadius: 8))
                        .offset(x: values.cgFloat("x"), y: values.cgFloat("y"))
                }
            },
            controls: { values in
                LabeledSlider(label: "X", value: values.cgFloat("x"), range: -70...70)
                LabeledSlider(label: "Y", value: values.cgFloat("y"), range: -70...70)
            },
            code: { values in
                """
                Text("Hello, SwiftUI")
                    .offset(
                        x: \(ExampleFormat.number(values.cgFloat("x"))),
                        y: \(ExampleFormat.number(values.cgFloat("y")))
                    )
                """
            }
        ),
        SwiftUIExample(
            id: "modifier.frame.basic",
            title: "Frame",
            summary: "Sets explicit layout dimensions.",
            match: SymbolExampleMatch(kind: .modifier, prefixes: ["frame"]),
            defaultValues: ExampleValues(doubles: ["width": 150, "height": 100]),
            preview: { values in
                Text("Hello, SwiftUI")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(
                        width: values.cgFloat("width", default: 150),
                        height: values.cgFloat("height", default: 100)
                    )
                    .background(.blue.gradient, in: .rect(cornerRadius: 8))
            },
            controls: { values in
                LabeledSlider(label: "Width", value: values.cgFloat("width", default: 150), range: 50...320)
                LabeledSlider(label: "Height", value: values.cgFloat("height", default: 100), range: 30...240)
            },
            code: { values in
                """
                Text("Hello, SwiftUI")
                    .frame(
                        width: \(ExampleFormat.number(values.cgFloat("width", default: 150))),
                        height: \(ExampleFormat.number(values.cgFloat("height", default: 100)))
                    )
                """
            }
        ),
        SwiftUIExample(
            id: "modifier.font.system",
            title: "System Font",
            summary: "Adjusts font size and weight.",
            match: SymbolExampleMatch(kind: .modifier, prefixes: ["font"]),
            defaultValues: ExampleValues(doubles: ["size": 24], ints: ["weight": ExampleFontWeight.regular.rawValue]),
            preview: { values in
                Text("Hello, SwiftUI")
                    .font(.system(
                        size: values.cgFloat("size", default: 24),
                        weight: ExampleFontWeight.selection(values.int("weight", default: ExampleFontWeight.regular.rawValue)).weight
                    ))
            },
            controls: { values in
                LabeledSlider(label: "Size", value: values.cgFloat("size", default: 24), range: 8...72)
                ExampleFontWeightPicker(selection: values.int("weight", default: ExampleFontWeight.regular.rawValue))
            },
            code: { values in
                let weight = ExampleFontWeight.selection(values.int("weight", default: ExampleFontWeight.regular.rawValue))
                return """
                Text("Hello, SwiftUI")
                    .font(.system(size: \(ExampleFormat.number(values.cgFloat("size", default: 24))), weight: .\(weight.code)))
                """
            }
        ),
        SwiftUIExample(
            id: "modifier.foregroundstyle.color",
            title: "Foreground Style",
            summary: "Applies a color style to text.",
            match: SymbolExampleMatch(kind: .modifier, prefixes: ["foreground"]),
            defaultValues: ExampleValues(colors: ["color": .blue]),
            preview: { values in
                Text("Hello, SwiftUI")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(values.color("color", default: .blue).color)
            },
            controls: { values in
                ExampleColorPicker(label: "Color", selection: values.color("color", default: .blue))
            },
            code: { values in
                """
                Text("Hello, SwiftUI")
                    .foregroundStyle(\(values.color("color", default: .blue).code))
                """
            }
        ),
        SwiftUIExample(
            id: "modifier.background.color",
            title: "Background",
            summary: "Adds a styled background behind text.",
            match: SymbolExampleMatch(kind: .modifier, prefixes: ["background"], excludingContains: ["task"]),
            defaultValues: ExampleValues(
                doubles: ["cornerRadius": 10],
                colors: ["color": .mint]
            ),
            preview: { values in
                Text("Hello, SwiftUI")
                    .font(.headline)
                    .padding()
                    .background(
                        values.color("color", default: .mint).color,
                        in: .rect(cornerRadius: values.cgFloat("cornerRadius", default: 10))
                    )
            },
            controls: { values in
                ExampleColorPicker(label: "Color", selection: values.color("color", default: .mint))
                LabeledSlider(label: "Corner Radius", value: values.cgFloat("cornerRadius", default: 10), range: 0...40)
            },
            code: { values in
                """
                Text("Hello, SwiftUI")
                    .padding()
                    .background(
                        \(values.color("color", default: .mint).code),
                        in: .rect(cornerRadius: \(ExampleFormat.number(values.cgFloat("cornerRadius", default: 10))))
                    )
                """
            }
        ),
    ]

    static let viewExamples: [SwiftUIExample] = [
        geometryReaderExample,
        canvasStrokeExample,
        canvasFillExample,
        textExample,
        imageExample,
        colorExample,
        shapeExample(.circle),
        shapeExample(.rectangle),
        shapeExample(.capsule),
        shapeExample(.ellipse),
        shapeExample(.roundedRectangle),
        stackExample(.vStack),
        stackExample(.hStack),
        stackExample(.zStack),
        scrollViewExample,
        gridExample,
        progressViewExample,
        gaugeExample,
        toggleExample,
        sliderExample,
        stepperExample,
    ]
}

// MARK: - View Examples

private extension SwiftUIExampleCatalog {
    static let geometryReaderExample = SwiftUIExample(
        id: "view.geometryReader.size",
        title: "Available Size",
        summary: "Reads the size proposed by the parent container.",
        match: SymbolExampleMatch(kind: .view, names: ["GeometryReader"]),
        defaultValues: ExampleValues(doubles: ["width": 250, "height": 180]),
        preview: { values in
            GeometryReader { proxy in
                VStack(spacing: 4) {
                    Text("Width: \(proxy.size.width, format: .number.precision(.fractionLength(0)))")
                    Text("Height: \(proxy.size.height, format: .number.precision(.fractionLength(0)))")
                }
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(.blue.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [5]))
                }
            }
            .frame(
                width: values.cgFloat("width", default: 250),
                height: values.cgFloat("height", default: 180)
            )
        },
        controls: { values in
            LabeledSlider(label: "Width", value: values.cgFloat("width", default: 250), range: 100...420)
            LabeledSlider(label: "Height", value: values.cgFloat("height", default: 180), range: 80...320)
        },
        code: { values in
            """
            GeometryReader { proxy in
                VStack {
                    Text("\\(proxy.size.width, format: .number)")
                    Text("\\(proxy.size.height, format: .number)")
                }
            }
            .frame(
                width: \(ExampleFormat.number(values.cgFloat("width", default: 250))),
                height: \(ExampleFormat.number(values.cgFloat("height", default: 180)))
            )
            """
        }
    )

    static let canvasStrokeExample = SwiftUIExample(
        id: "view.canvas.stroke",
        title: "Stroke a Shape",
        summary: "Draws a selected shape with configurable stroke, frame, and inset.",
        match: SymbolExampleMatch(kind: .view, names: ["Canvas"]),
        defaultValues: ExampleValues(
            doubles: ["lineWidth": 3, "width": 200, "height": 200, "inset": 20, "cornerRadius": 18],
            ints: ["shape": CanvasShapeChoice.circle.rawValue],
            colors: ["stroke": .blue]
        ),
        preview: { values in
            let shape = CanvasShapeChoice.selection(values.int("shape"))
            let inset = values.cgFloat("inset", default: 20)
            let cornerRadius = values.cgFloat("cornerRadius", default: 18)
            Canvas { context, size in
                let rect = CGRect(origin: .zero, size: size).insetBy(dx: inset, dy: inset)
                context.stroke(
                    shape.path(in: rect, cornerRadius: cornerRadius),
                    with: .color(values.color("stroke", default: .blue).color),
                    lineWidth: values.cgFloat("lineWidth", default: 3)
                )
            }
            .frame(
                width: values.cgFloat("width", default: 200),
                height: values.cgFloat("height", default: 200)
            )
        },
        controls: { values in
            CanvasShapePicker(selection: values.int("shape"))
            ExampleColorPicker(label: "Stroke Color", selection: values.color("stroke", default: .blue))
            LabeledSlider(label: "Line Width", value: values.cgFloat("lineWidth", default: 3), range: 1...20)
            LabeledSlider(label: "Width", value: values.cgFloat("width", default: 200), range: 80...360)
            LabeledSlider(label: "Height", value: values.cgFloat("height", default: 200), range: 80...320)
            LabeledSlider(label: "Inset", value: values.cgFloat("inset", default: 20), range: 0...60)
        },
        code: { values in
            let shape = CanvasShapeChoice.selection(values.int("shape"))
            return """
            Canvas { context, size in
                let rect = CGRect(origin: .zero, size: size)
                    .insetBy(dx: \(ExampleFormat.number(values.cgFloat("inset", default: 20))), dy: \(ExampleFormat.number(values.cgFloat("inset", default: 20))))

                context.stroke(
                    \(shape.pathCode(cornerRadius: values.cgFloat("cornerRadius", default: 18))),
                    with: .color(\(values.color("stroke", default: .blue).code)),
                    lineWidth: \(ExampleFormat.number(values.cgFloat("lineWidth", default: 3)))
                )
            }
            .frame(
                width: \(ExampleFormat.number(values.cgFloat("width", default: 200))),
                height: \(ExampleFormat.number(values.cgFloat("height", default: 200)))
            )
            """
        }
    )

    static let canvasFillExample = SwiftUIExample(
        id: "view.canvas.fillAndStroke",
        title: "Fill and Stroke",
        summary: "Combines fill and stroke drawing calls in one canvas.",
        match: SymbolExampleMatch(kind: .view, names: ["Canvas"]),
        defaultValues: ExampleValues(
            doubles: ["lineWidth": 4, "width": 220, "height": 160, "inset": 18, "cornerRadius": 24],
            ints: ["shape": CanvasShapeChoice.roundedRectangle.rawValue],
            colors: ["fill": .mint, "stroke": .indigo]
        ),
        preview: { values in
            let shape = CanvasShapeChoice.selection(values.int("shape", default: CanvasShapeChoice.roundedRectangle.rawValue))
            let inset = values.cgFloat("inset", default: 18)
            let cornerRadius = values.cgFloat("cornerRadius", default: 24)
            Canvas { context, size in
                let rect = CGRect(origin: .zero, size: size).insetBy(dx: inset, dy: inset)
                let path = shape.path(in: rect, cornerRadius: cornerRadius)
                context.fill(path, with: .color(values.color("fill", default: .mint).color))
                context.stroke(
                    path,
                    with: .color(values.color("stroke", default: .indigo).color),
                    lineWidth: values.cgFloat("lineWidth", default: 4)
                )
            }
            .frame(
                width: values.cgFloat("width", default: 220),
                height: values.cgFloat("height", default: 160)
            )
        },
        controls: { values in
            CanvasShapePicker(selection: values.int("shape", default: CanvasShapeChoice.roundedRectangle.rawValue))
            ExampleColorPicker(label: "Fill Color", selection: values.color("fill", default: .mint))
            ExampleColorPicker(label: "Stroke Color", selection: values.color("stroke", default: .indigo))
            LabeledSlider(label: "Line Width", value: values.cgFloat("lineWidth", default: 4), range: 1...20)
            LabeledSlider(label: "Width", value: values.cgFloat("width", default: 220), range: 80...360)
            LabeledSlider(label: "Height", value: values.cgFloat("height", default: 160), range: 80...320)
            LabeledSlider(label: "Inset", value: values.cgFloat("inset", default: 18), range: 0...60)
        },
        code: { values in
            let shape = CanvasShapeChoice.selection(values.int("shape", default: CanvasShapeChoice.roundedRectangle.rawValue))
            return """
            Canvas { context, size in
                let rect = CGRect(origin: .zero, size: size)
                    .insetBy(dx: \(ExampleFormat.number(values.cgFloat("inset", default: 18))), dy: \(ExampleFormat.number(values.cgFloat("inset", default: 18))))
                let path = \(shape.pathCode(cornerRadius: values.cgFloat("cornerRadius", default: 24)))

                context.fill(path, with: .color(\(values.color("fill", default: .mint).code)))
                context.stroke(
                    path,
                    with: .color(\(values.color("stroke", default: .indigo).code)),
                    lineWidth: \(ExampleFormat.number(values.cgFloat("lineWidth", default: 4)))
                )
            }
            .frame(
                width: \(ExampleFormat.number(values.cgFloat("width", default: 220))),
                height: \(ExampleFormat.number(values.cgFloat("height", default: 160)))
            )
            """
        }
    )

    static let textExample = SwiftUIExample(
        id: "view.text.styled",
        title: "Styled Text",
        summary: "Edits the string, color, font size, and weight.",
        match: SymbolExampleMatch(kind: .view, names: ["Text"]),
        defaultValues: ExampleValues(
            doubles: ["size": 24],
            ints: ["weight": ExampleFontWeight.regular.rawValue],
            strings: ["text": "Hello, SwiftUI"],
            colors: ["color": .primary]
        ),
        preview: { values in
            Text(values.string("text", default: "Hello, SwiftUI"))
                .font(.system(
                    size: values.cgFloat("size", default: 24),
                    weight: ExampleFontWeight.selection(values.int("weight", default: ExampleFontWeight.regular.rawValue)).weight
                ))
                .foregroundStyle(values.color("color", default: .primary).color)
        },
        controls: { values in
            TextField("Text", text: values.string("text", default: "Hello, SwiftUI"))
            LabeledSlider(label: "Font Size", value: values.cgFloat("size", default: 24), range: 8...72)
            ExampleFontWeightPicker(selection: values.int("weight", default: ExampleFontWeight.regular.rawValue))
            ExampleColorPicker(label: "Color", selection: values.color("color", default: .primary))
        },
        code: { values in
            let weight = ExampleFontWeight.selection(values.int("weight", default: ExampleFontWeight.regular.rawValue))
            return """
            Text(\(ExampleFormat.stringLiteral(values.string("text", default: "Hello, SwiftUI"))))
                .font(.system(size: \(ExampleFormat.number(values.cgFloat("size", default: 24))), weight: .\(weight.code)))
                .foregroundStyle(\(values.color("color", default: .primary).code))
            """
        }
    )

    static let imageExample = SwiftUIExample(
        id: "view.image.symbol",
        title: "SF Symbol Image",
        summary: "Renders an SF Symbol with size and color controls.",
        match: SymbolExampleMatch(kind: .view, names: ["Image"]),
        defaultValues: ExampleValues(
            doubles: ["size": 46],
            strings: ["symbol": "star.fill"],
            colors: ["color": .blue]
        ),
        preview: { values in
            Image(systemName: values.string("symbol", default: "star.fill"))
                .font(.system(size: values.cgFloat("size", default: 46)))
                .foregroundStyle(values.color("color", default: .blue).color)
                .symbolEffect(.pulse, options: .repeating.speed(0.5))
        },
        controls: { values in
            TextField("SF Symbol", text: values.string("symbol", default: "star.fill"))
            LabeledSlider(label: "Size", value: values.cgFloat("size", default: 46), range: 12...110)
            ExampleColorPicker(label: "Color", selection: values.color("color", default: .blue))
        },
        code: { values in
            """
            Image(systemName: \(ExampleFormat.stringLiteral(values.string("symbol", default: "star.fill"))))
                .font(.system(size: \(ExampleFormat.number(values.cgFloat("size", default: 46)))))
                .foregroundStyle(\(values.color("color", default: .blue).code))
            """
        }
    )

    static let colorExample = SwiftUIExample(
        id: "view.color.hsb",
        title: "HSB Color",
        summary: "Creates a color from hue, saturation, and brightness.",
        match: SymbolExampleMatch(kind: .view, names: ["Color"]),
        defaultValues: ExampleValues(
            doubles: ["hue": 0.6, "saturation": 0.8, "brightness": 0.9, "width": 140, "height": 120, "cornerRadius": 12]
        ),
        preview: { values in
            Color(
                hue: values.double("hue", default: 0.6),
                saturation: values.double("saturation", default: 0.8),
                brightness: values.double("brightness", default: 0.9)
            )
            .frame(
                width: values.cgFloat("width", default: 140),
                height: values.cgFloat("height", default: 120)
            )
            .clipShape(.rect(cornerRadius: values.cgFloat("cornerRadius", default: 12)))
            .shadow(radius: 4)
        },
        controls: { values in
            LabeledSlider(label: "Hue", value: values.cgFloat("hue", default: 0.6), range: 0...1, unit: "", step: 0.01)
            LabeledSlider(
                label: "Saturation",
                value: values.cgFloat("saturation", default: 0.8),
                range: 0...1,
                unit: "",
                step: 0.01
            )
            LabeledSlider(
                label: "Brightness",
                value: values.cgFloat("brightness", default: 0.9),
                range: 0...1,
                unit: "",
                step: 0.01
            )
            LabeledSlider(label: "Width", value: values.cgFloat("width", default: 140), range: 50...320)
            LabeledSlider(label: "Height", value: values.cgFloat("height", default: 120), range: 50...260)
            LabeledSlider(label: "Corner Radius", value: values.cgFloat("cornerRadius", default: 12), range: 0...40)
        },
        code: { values in
            """
            Color(
                hue: \(ExampleFormat.number(values.double("hue", default: 0.6))),
                saturation: \(ExampleFormat.number(values.double("saturation", default: 0.8))),
                brightness: \(ExampleFormat.number(values.double("brightness", default: 0.9)))
            )
            .frame(
                width: \(ExampleFormat.number(values.cgFloat("width", default: 140))),
                height: \(ExampleFormat.number(values.cgFloat("height", default: 120)))
            )
            .clipShape(.rect(cornerRadius: \(ExampleFormat.number(values.cgFloat("cornerRadius", default: 12)))))
            """
        }
    )

    static let scrollViewExample = SwiftUIExample(
        id: "view.scrollView.axis",
        title: "Scrollable Items",
        summary: "Switches between vertical and horizontal scrolling.",
        match: SymbolExampleMatch(kind: .view, names: ["ScrollView"]),
        defaultValues: ExampleValues(
            doubles: ["height": 180],
            ints: ["items": 20, "axis": ScrollAxisChoice.vertical.rawValue]
        ),
        preview: { values in
            let axis = ScrollAxisChoice.selection(values.int("axis", default: ScrollAxisChoice.vertical.rawValue))
            Group {
                if axis == .vertical {
                    ScrollView(.vertical) {
                        VStack(spacing: 8) {
                            ForEach(0..<values.int("items", default: 20), id: \.self) { index in
                                Text("Row \(index)")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(.blue.opacity(0.08), in: .rect(cornerRadius: 6))
                            }
                        }
                        .padding(8)
                    }
                } else {
                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            ForEach(0..<values.int("items", default: 20), id: \.self) { index in
                                Text("\(index)")
                                    .frame(width: 50, height: 50)
                                    .background(.blue.opacity(0.15), in: .rect(cornerRadius: 8))
                            }
                        }
                        .padding(8)
                    }
                }
            }
            .frame(height: values.cgFloat("height", default: 180))
            .frame(maxWidth: 300)
        },
        controls: { values in
            ScrollAxisPicker(selection: values.int("axis", default: ScrollAxisChoice.vertical.rawValue))
            Stepper("Items: \(values.wrappedValue.int("items", default: 20))", value: values.int("items", default: 20), in: 1...50)
            LabeledSlider(label: "Height", value: values.cgFloat("height", default: 180), range: 80...320)
        },
        code: { values in
            let axis = ScrollAxisChoice.selection(values.int("axis", default: ScrollAxisChoice.vertical.rawValue))
            let stack = axis == .vertical ? "VStack" : "HStack"
            return """
            ScrollView(.\(axis.code)) {
                \(stack)(spacing: 8) {
                    ForEach(0..<\(values.int("items", default: 20)), id: \\.self) { index in
                        Text("Item \\(index)")
                    }
                }
                .padding(8)
            }
            .frame(height: \(ExampleFormat.number(values.cgFloat("height", default: 180))))
            """
        }
    )

    static let gridExample = SwiftUIExample(
        id: "view.grid.lazy",
        title: "Lazy Grid",
        summary: "Adjusts columns, spacing, and item count.",
        match: SymbolExampleMatch(kind: .view, names: ["Grid", "LazyVGrid", "LazyHGrid"]),
        defaultValues: ExampleValues(doubles: ["spacing": 8], ints: ["columns": 3, "items": 9]),
        preview: { values in
            LazyVGrid(
                columns: Array(
                    repeating: GridItem(.flexible(), spacing: values.cgFloat("spacing", default: 8)),
                    count: values.int("columns", default: 3)
                ),
                spacing: values.cgFloat("spacing", default: 8)
            ) {
                ForEach(0..<values.int("items", default: 9), id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.blue.gradient)
                        .frame(height: 44)
                }
            }
            .frame(maxWidth: 280)
            .padding(8)
        },
        controls: { values in
            Stepper("Columns: \(values.wrappedValue.int("columns", default: 3))", value: values.int("columns", default: 3), in: 1...6)
            LabeledSlider(label: "Spacing", value: values.cgFloat("spacing", default: 8), range: 0...24)
            Stepper("Items: \(values.wrappedValue.int("items", default: 9))", value: values.int("items", default: 9), in: 1...30)
        },
        code: { values in
            """
            LazyVGrid(
                columns: Array(
                    repeating: GridItem(.flexible()),
                    count: \(values.int("columns", default: 3))
                ),
                spacing: \(ExampleFormat.number(values.cgFloat("spacing", default: 8)))
            ) {
                ForEach(0..<\(values.int("items", default: 9)), id: \\.self) { _ in
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.blue.gradient)
                        .frame(height: 44)
                }
            }
            """
        }
    )

    static let progressViewExample = SwiftUIExample(
        id: "view.progressView.linear",
        title: "Linear Progress",
        summary: "Shows completion as a value between zero and one.",
        match: SymbolExampleMatch(kind: .view, names: ["ProgressView"]),
        defaultValues: ExampleValues(doubles: ["value": 0.65]),
        preview: { values in
            VStack(spacing: 12) {
                ProgressView(value: values.double("value", default: 0.65), total: 1) {
                    Text("Progress")
                }
                .progressViewStyle(.linear)
                Text(values.double("value", default: 0.65), format: .percent)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 220)
        },
        controls: { values in
            LabeledSlider(label: "Progress", value: values.cgFloat("value", default: 0.65), range: 0...1, unit: "", step: 0.01)
        },
        code: { values in
            """
            ProgressView(value: \(ExampleFormat.number(values.double("value", default: 0.65))), total: 1.0) {
                Text("Progress")
            }
            .progressViewStyle(.linear)
            """
        }
    )

    static let gaugeExample = SwiftUIExample(
        id: "view.gauge.circular",
        title: "Circular Gauge",
        summary: "Displays a bounded measurement.",
        match: SymbolExampleMatch(kind: .view, names: ["Gauge"]),
        defaultValues: ExampleValues(doubles: ["value": 0.65]),
        preview: { values in
            Gauge(value: values.double("value", default: 0.65), in: 0...1) {
                Text("Level")
            } currentValueLabel: {
                Text(values.double("value", default: 0.65), format: .percent)
            }
            .gaugeStyle(.accessoryCircular)
            .scaleEffect(1.5)
        },
        controls: { values in
            LabeledSlider(label: "Value", value: values.cgFloat("value", default: 0.65), range: 0...1, unit: "", step: 0.01)
        },
        code: { values in
            """
            Gauge(value: \(ExampleFormat.number(values.double("value", default: 0.65))), in: 0...1) {
                Text("Level")
            } currentValueLabel: {
                Text(\(ExampleFormat.stringLiteral(ExampleFormat.percent(values.double("value", default: 0.65)))))
            }
            .gaugeStyle(.accessoryCircular)
            """
        }
    )

    static let toggleExample = SwiftUIExample(
        id: "view.toggle.switch",
        title: "Switch Toggle",
        summary: "Shows a boolean control state.",
        match: SymbolExampleMatch(kind: .view, names: ["Toggle"]),
        defaultValues: ExampleValues(bools: ["isOn": true]),
        preview: { values in
            Toggle(values.bool("isOn", default: true) ? "Enabled" : "Disabled", isOn: .constant(values.bool("isOn", default: true)))
                .toggleStyle(.switch)
                .frame(width: 190)
        },
        controls: { values in
            Toggle("Is On", isOn: values.bool("isOn", default: true))
        },
        code: { values in
            """
            @State private var isEnabled = \(values.bool("isOn", default: true))

            Toggle(\(ExampleFormat.stringLiteral(values.bool("isOn", default: true) ? "Enabled" : "Disabled")), isOn: $isEnabled)
                .toggleStyle(.switch)
            """
        }
    )

    static let sliderExample = SwiftUIExample(
        id: "view.slider.value",
        title: "Bound Value",
        summary: "Adjusts a numeric binding over a range.",
        match: SymbolExampleMatch(kind: .view, names: ["Slider"]),
        defaultValues: ExampleValues(doubles: ["value": 50]),
        preview: { values in
            VStack(spacing: 8) {
                Slider(value: .constant(values.double("value", default: 50)), in: 0...100)
                    .frame(width: 220)
                Text(values.double("value", default: 50), format: .number.precision(.fractionLength(0)))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        },
        controls: { values in
            LabeledSlider(label: "Value", value: values.cgFloat("value", default: 50), range: 0...100, unit: "", step: 1)
        },
        code: { values in
            """
            @State private var value = \(ExampleFormat.number(values.double("value", default: 50)))

            Slider(value: $value, in: 0...100) {
                Text("Value")
            }
            """
        }
    )

    static let stepperExample = SwiftUIExample(
        id: "view.stepper.value",
        title: "Bound Count",
        summary: "Increments and decrements an integer binding.",
        match: SymbolExampleMatch(kind: .view, names: ["Stepper"]),
        defaultValues: ExampleValues(ints: ["value": 5]),
        preview: { values in
            Stepper("Count: \(values.int("value", default: 5))", value: .constant(values.int("value", default: 5)), in: 0...20)
                .frame(width: 220)
        },
        controls: { values in
            Stepper("Value: \(values.wrappedValue.int("value", default: 5))", value: values.int("value", default: 5), in: 0...20)
        },
        code: { values in
            """
            @State private var count = \(values.int("value", default: 5))

            Stepper("Count: \\(count)", value: $count, in: 0...20)
            """
        }
    )
}

private extension SwiftUIExampleCatalog {
    static func shapeExample(_ shape: ShapeExampleKind) -> SwiftUIExample {
        SwiftUIExample(
            id: "view.\(shape.rawValue).shape",
            title: shape.title,
            summary: "Configures fill, stroke, and frame values.",
            match: SymbolExampleMatch(kind: .view, names: shape.symbolNames),
            defaultValues: ExampleValues(
                doubles: ["strokeWidth": 3, "width": 120, "height": 120, "cornerRadius": 20],
                colors: ["fill": .blue, "stroke": .cyan]
            ),
            preview: { values in
                shape.preview(values: values)
            },
            controls: { values in
                ExampleColorPicker(label: "Fill", selection: values.color("fill", default: .blue))
                ExampleColorPicker(label: "Stroke", selection: values.color("stroke", default: .cyan))
                LabeledSlider(label: "Stroke Width", value: values.cgFloat("strokeWidth", default: 3), range: 0...16)
                LabeledSlider(label: "Width", value: values.cgFloat("width", default: 120), range: 40...280)
                if shape.usesIndependentHeight {
                    LabeledSlider(label: "Height", value: values.cgFloat("height", default: 120), range: 40...260)
                }
                if shape == .roundedRectangle {
                    LabeledSlider(label: "Corner Radius", value: values.cgFloat("cornerRadius", default: 20), range: 0...70)
                }
            },
            code: { values in
                shape.code(values: values)
            }
        )
    }

    static func stackExample(_ stack: StackExampleKind) -> SwiftUIExample {
        SwiftUIExample(
            id: "view.\(stack.rawValue).layout",
            title: stack.title,
            summary: "Adjusts spacing, item count, and alignment.",
            match: SymbolExampleMatch(kind: .view, names: [stack.symbolName]),
            defaultValues: ExampleValues(
                doubles: ["spacing": 10],
                ints: ["items": 4, "alignment": 1]
            ),
            preview: { values in
                stack.preview(values: values)
            },
            controls: { values in
                LabeledSlider(label: "Spacing", value: values.cgFloat("spacing", default: 10), range: 0...50)
                Stepper("Items: \(values.wrappedValue.int("items", default: 4))", value: values.int("items", default: 4), in: 1...8)
                if stack != .zStack {
                    StackAlignmentPicker(stack: stack, selection: values.int("alignment", default: 1))
                }
            },
            code: { values in
                stack.code(values: values)
            }
        )
    }
}

// MARK: - Live Preview

struct LivePreviewCanvas: View {
    let example: SwiftUIExample
    let values: ExampleValues

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Label("Live Preview", systemImage: "play.fill")
                    .font(.headline)
                Spacer()
                Text(example.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            ZStack {
                CheckerboardBackground()
                    .clipShape(.rect(cornerRadius: 10))

                example.preview(values: values)
                    .padding(20)
                    .frame(maxWidth: .infinity, minHeight: 220)
                    .animation(.smooth(duration: 0.2), value: values)
            }
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 10).fill(.background)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(.quaternary, lineWidth: 1)
            }

            if !example.summary.isEmpty {
                Text(example.summary)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.quaternary, lineWidth: 1)
        }
    }
}

struct ExamplePicker: View {
    let examples: [SwiftUIExample]
    @Binding var selection: String

    var body: some View {
        Picker("Example", selection: $selection) {
            ForEach(examples) { example in
                Text(example.title).tag(example.id)
            }
        }
        .pickerStyle(.segmented)
        .id(examples.map(\.id).joined(separator: "|"))
    }
}

// MARK: - Inspector Panel

struct SymbolInspectorPanel: View {
    let symbol: IndexedSwiftSymbol
    let interactiveSymbol: InteractiveSymbol?
    @Binding var state: PlaygroundState
    @Environment(\.colorScheme) private var colorScheme
    @State private var summaryGenerator = SymbolSummaryGenerator()

    private var selectedExample: SwiftUIExample? {
        guard let interactiveSymbol else { return nil }
        return state.selectedExample(for: interactiveSymbol)
    }

    private var summaryContext: SymbolSummaryContext {
        let example = selectedExample
        let values = example.map { state.values(for: $0) }

        return SymbolSummaryContext(
            name: symbol.name,
            kind: symbol.kind.singularTitle,
            category: symbol.categoryName,
            declaration: symbol.declaration,
            defaultInstantiation: symbol.defaultInstantiation.strippingTokenize,
            exampleTitle: example?.title,
            exampleSummary: example?.summary,
            exampleCode: example.flatMap { example in
                values.map { example.code(values: $0) }
            }
        )
    }

    var body: some View {
        Form {
            Section {
                Label(symbol.name, systemImage: symbol.kind.systemImage)
                    .font(.headline)
            }

            if let interactiveSymbol, interactiveSymbol.examples.count > 1, let selectedExample {
                Section("Example") {
                    ExamplePicker(
                        examples: interactiveSymbol.examples,
                        selection: selectedExampleIDBinding(fallback: selectedExample.id)
                    )
                }
            }

            if let selectedExample {
                Section("Controls") {
                    selectedExample.controls(values: valuesBinding(for: selectedExample))
                        .id(selectedExample.id)
                }

                Section {
                    Button("Reset Example") {
                        withAnimation {
                            state.reset(selectedExample)
                        }
                    }
                }

                Section("Generated Code") {
                    Text(SwiftSyntaxHighlighter.highlight(
                        selectedExample.code(values: state.values(for: selectedExample)),
                        colorScheme: colorScheme
                    ))
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                }
            }

            FoundationModelSummarySection(
                generator: summaryGenerator,
                context: summaryContext
            )
        }
        .formStyle(.grouped)
        .onAppear {
            if let interactiveSymbol {
                state.prepare(for: interactiveSymbol)
            }
        }
        .onChange(of: symbol.stableID) {
            summaryGenerator.reset()
            if let interactiveSymbol {
                state.prepare(for: interactiveSymbol)
            }
        }
    }

    private func selectedExampleIDBinding(fallback: String) -> Binding<String> {
        Binding(
            get: { state.selectedExampleID ?? fallback },
            set: { newValue in
                guard let interactiveSymbol else { return }
                state.selectExample(id: newValue, for: interactiveSymbol)
            }
        )
    }

    private func valuesBinding(for example: SwiftUIExample) -> Binding<ExampleValues> {
        Binding(
            get: { state.values(for: example) },
            set: { state.valuesByExampleID[example.id] = $0 }
        )
    }
}

private struct FoundationModelSummarySection: View {
    let generator: SymbolSummaryGenerator
    let context: SymbolSummaryContext

    private var message: String? {
        generator.statusMessage ?? generator.unavailableMessage
    }

    var body: some View {
        Section("Foundation Model") {
            if !generator.summary.isEmpty {
                Text(generator.summary)
                    .font(.callout)
                    .textSelection(.enabled)
            }

            if let message {
                Label(message, systemImage: generator.unavailableMessage == nil ? "info.circle" : "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if generator.isStreaming {
                ProgressView()
                    .controlSize(.small)
            }

            Button {
                generator.generateSummary(for: context)
            } label: {
                Label(buttonTitle, systemImage: "sparkles")
            }
            .disabled(!generator.canGenerate)
        }
    }

    private var buttonTitle: String {
        if generator.isStreaming {
            return "Summarizing"
        }

        return generator.summary.isEmpty ? "Summarize Usage" : "Regenerate Summary"
    }
}

// MARK: - Shared Controls

struct LabeledSlider: View {
    let label: String
    @Binding var value: CGFloat
    let range: ClosedRange<CGFloat>
    var unit: String = "pt"
    var step: CGFloat = 1

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label).font(.subheadline)
                Spacer()
                Text(formattedValue)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Slider(value: $value, in: range, step: step)
        }
    }

    private var formattedValue: String {
        let valueString = ExampleFormat.number(value)
        return unit.isEmpty ? valueString : "\(valueString) \(unit)"
    }
}

struct ExampleColorPicker: View {
    let label: String
    @Binding var selection: ExampleColor

    var body: some View {
        Picker(label, selection: $selection) {
            ForEach(ExampleColor.allCases) { color in
                HStack {
                    Circle()
                        .fill(color.color)
                        .frame(width: 12, height: 12)
                        .overlay {
                            Circle().strokeBorder(.secondary.opacity(0.25), lineWidth: 1)
                        }
                    Text(color.title)
                }
                .tag(color)
            }
        }
    }
}

struct ExampleFontWeightPicker: View {
    @Binding var selection: Int

    var body: some View {
        Picker("Weight", selection: $selection) {
            ForEach(ExampleFontWeight.allCases) { weight in
                Text(weight.title).tag(weight.rawValue)
            }
        }
    }
}

struct CanvasShapePicker: View {
    @Binding var selection: Int

    var body: some View {
        Picker("Shape", selection: $selection) {
            ForEach(CanvasShapeChoice.allCases) { shape in
                Text(shape.title).tag(shape.rawValue)
            }
        }
    }
}

struct StackAlignmentPicker: View {
    let stack: StackExampleKind
    @Binding var selection: Int

    var body: some View {
        Picker("Alignment", selection: $selection) {
            Text(stack == .vStack ? "Leading" : "Top").tag(0)
            Text("Center").tag(1)
            Text(stack == .vStack ? "Trailing" : "Bottom").tag(2)
        }
    }
}

struct ScrollAxisPicker: View {
    @Binding var selection: Int

    var body: some View {
        Picker("Direction", selection: $selection) {
            ForEach(ScrollAxisChoice.allCases) { axis in
                Text(axis.title).tag(axis.rawValue)
            }
        }
        .pickerStyle(.segmented)
    }
}

// MARK: - Supporting Types

enum ScrollAxisChoice: Int, CaseIterable, Identifiable {
    case vertical
    case horizontal

    var id: Int { rawValue }

    static func selection(_ value: Int) -> ScrollAxisChoice {
        ScrollAxisChoice(rawValue: value) ?? .vertical
    }

    var title: String {
        switch self {
        case .vertical: "Vertical"
        case .horizontal: "Horizontal"
        }
    }

    var code: String {
        switch self {
        case .vertical: "vertical"
        case .horizontal: "horizontal"
        }
    }
}

enum ExampleColor: String, CaseIterable, Identifiable {
    case primary
    case secondary
    case blue
    case cyan
    case mint
    case indigo
    case purple
    case pink
    case red
    case orange
    case yellow
    case green
    case teal
    case gray
    case black
    case white
    case clear

    var id: String { rawValue }

    var title: String {
        switch self {
        case .primary: "Primary"
        case .secondary: "Secondary"
        case .blue: "Blue"
        case .cyan: "Cyan"
        case .mint: "Mint"
        case .indigo: "Indigo"
        case .purple: "Purple"
        case .pink: "Pink"
        case .red: "Red"
        case .orange: "Orange"
        case .yellow: "Yellow"
        case .green: "Green"
        case .teal: "Teal"
        case .gray: "Gray"
        case .black: "Black"
        case .white: "White"
        case .clear: "Clear"
        }
    }

    var color: Color {
        switch self {
        case .primary: .primary
        case .secondary: .secondary
        case .blue: .blue
        case .cyan: .cyan
        case .mint: .mint
        case .indigo: .indigo
        case .purple: .purple
        case .pink: .pink
        case .red: .red
        case .orange: .orange
        case .yellow: .yellow
        case .green: .green
        case .teal: .teal
        case .gray: .gray
        case .black: .black
        case .white: .white
        case .clear: .clear
        }
    }

    var code: String {
        ".\(rawValue)"
    }
}

enum ExampleFontWeight: Int, CaseIterable, Identifiable {
    case ultraLight
    case thin
    case light
    case regular
    case medium
    case semibold
    case bold
    case heavy
    case black

    var id: Int { rawValue }

    static func selection(_ value: Int) -> ExampleFontWeight {
        ExampleFontWeight(rawValue: value) ?? .regular
    }

    var title: String {
        switch self {
        case .ultraLight: "Ultra Light"
        case .thin: "Thin"
        case .light: "Light"
        case .regular: "Regular"
        case .medium: "Medium"
        case .semibold: "Semibold"
        case .bold: "Bold"
        case .heavy: "Heavy"
        case .black: "Black"
        }
    }

    var code: String {
        switch self {
        case .ultraLight: "ultraLight"
        case .thin: "thin"
        case .light: "light"
        case .regular: "regular"
        case .medium: "medium"
        case .semibold: "semibold"
        case .bold: "bold"
        case .heavy: "heavy"
        case .black: "black"
        }
    }

    var weight: Font.Weight {
        switch self {
        case .ultraLight: .ultraLight
        case .thin: .thin
        case .light: .light
        case .regular: .regular
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        case .heavy: .heavy
        case .black: .black
        }
    }
}

enum CanvasShapeChoice: Int, CaseIterable, Identifiable {
    case circle
    case rectangle
    case roundedRectangle

    var id: Int { rawValue }

    static func selection(_ value: Int) -> CanvasShapeChoice {
        CanvasShapeChoice(rawValue: value) ?? .circle
    }

    var title: String {
        switch self {
        case .circle: "Circle"
        case .rectangle: "Rectangle"
        case .roundedRectangle: "Rounded Rect"
        }
    }

    func path(in rect: CGRect, cornerRadius: CGFloat) -> Path {
        switch self {
        case .circle:
            Circle().path(in: rect)
        case .rectangle:
            Rectangle().path(in: rect)
        case .roundedRectangle:
            RoundedRectangle(cornerRadius: cornerRadius).path(in: rect)
        }
    }

    func pathCode(cornerRadius: CGFloat) -> String {
        switch self {
        case .circle:
            "Circle().path(in: rect)"
        case .rectangle:
            "Rectangle().path(in: rect)"
        case .roundedRectangle:
            "RoundedRectangle(cornerRadius: \(ExampleFormat.number(cornerRadius))).path(in: rect)"
        }
    }
}

enum ShapeExampleKind: String {
    case circle
    case rectangle
    case capsule
    case ellipse
    case roundedRectangle

    var title: String {
        switch self {
        case .circle: "Circle Shape"
        case .rectangle: "Rectangle Shape"
        case .capsule: "Capsule Shape"
        case .ellipse: "Ellipse Shape"
        case .roundedRectangle: "Rounded Rectangle"
        }
    }

    var symbolNames: [String] {
        switch self {
        case .circle: ["Circle"]
        case .rectangle: ["Rectangle"]
        case .capsule: ["Capsule"]
        case .ellipse: ["Ellipse"]
        case .roundedRectangle: ["RoundedRectangle", "UnevenRoundedRectangle"]
        }
    }

    var usesIndependentHeight: Bool {
        self != .circle
    }

    @ViewBuilder
    func preview(values: ExampleValues) -> some View {
        let fill = values.color("fill", default: .blue).color
        let stroke = values.color("stroke", default: .cyan).color
        let strokeWidth = values.cgFloat("strokeWidth", default: 3)
        let width = values.cgFloat("width", default: 120)
        let height = usesIndependentHeight ? values.cgFloat("height", default: 120) : width
        let cornerRadius = values.cgFloat("cornerRadius", default: 20)

        switch self {
        case .circle:
            Circle()
                .fill(fill)
                .overlay { Circle().stroke(stroke, lineWidth: strokeWidth) }
                .frame(width: width, height: width)
        case .rectangle:
            Rectangle()
                .fill(fill)
                .overlay { Rectangle().stroke(stroke, lineWidth: strokeWidth) }
                .frame(width: width, height: height)
        case .capsule:
            Capsule()
                .fill(fill)
                .overlay { Capsule().stroke(stroke, lineWidth: strokeWidth) }
                .frame(width: width, height: height)
        case .ellipse:
            Ellipse()
                .fill(fill)
                .overlay { Ellipse().stroke(stroke, lineWidth: strokeWidth) }
                .frame(width: width, height: height)
        case .roundedRectangle:
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(fill)
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(stroke, lineWidth: strokeWidth)
                }
                .frame(width: width, height: height)
        }
    }

    func code(values: ExampleValues) -> String {
        let fill = values.color("fill", default: .blue).code
        let stroke = values.color("stroke", default: .cyan).code
        let strokeWidth = ExampleFormat.number(values.cgFloat("strokeWidth", default: 3))
        let width = ExampleFormat.number(values.cgFloat("width", default: 120))
        let height = ExampleFormat.number(
            usesIndependentHeight
            ? values.cgFloat("height", default: 120)
            : values.cgFloat("width", default: 120)
        )
        let shapeLine = shapeCode(values: values)

        return """
        \(shapeLine)
            .fill(\(fill))
            .overlay {
                \(shapeLine).stroke(\(stroke), lineWidth: \(strokeWidth))
            }
            .frame(width: \(width), height: \(height))
        """
    }

    private func shapeCode(values: ExampleValues) -> String {
        switch self {
        case .circle: "Circle()"
        case .rectangle: "Rectangle()"
        case .capsule: "Capsule()"
        case .ellipse: "Ellipse()"
        case .roundedRectangle:
            "RoundedRectangle(cornerRadius: \(ExampleFormat.number(values.cgFloat("cornerRadius", default: 20))))"
        }
    }
}

enum StackExampleKind: String {
    case vStack
    case hStack
    case zStack

    var symbolName: String {
        switch self {
        case .vStack: "VStack"
        case .hStack: "HStack"
        case .zStack: "ZStack"
        }
    }

    var title: String {
        switch self {
        case .vStack: "Vertical Stack"
        case .hStack: "Horizontal Stack"
        case .zStack: "Layered Stack"
        }
    }

    @ViewBuilder
    func preview(values: ExampleValues) -> some View {
        let spacing = values.cgFloat("spacing", default: 10)
        let items = values.int("items", default: 4)
        let alignment = values.int("alignment", default: 1)

        switch self {
        case .vStack:
            VStack(alignment: horizontalAlignment(alignment), spacing: spacing) {
                ForEach(0..<items, id: \.self) { index in
                    Text("Item \(index)")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.blue.opacity(0.15), in: .rect(cornerRadius: 6))
                }
            }
        case .hStack:
            HStack(alignment: verticalAlignment(alignment), spacing: spacing) {
                ForEach(0..<items, id: \.self) { index in
                    Text("\(index)")
                        .font(.caption.bold())
                        .frame(width: 32, height: 32)
                        .background(.blue.opacity(0.15), in: .rect(cornerRadius: 6))
                }
            }
        case .zStack:
            ZStack {
                ForEach(0..<items, id: \.self) { index in
                    let factor = Double(index + 1) / Double(max(items, 1))
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.blue.opacity(factor))
                        .frame(
                            width: CGFloat(max(32, 130 - index * 20)),
                            height: CGFloat(max(32, 130 - index * 20))
                        )
                        .offset(x: CGFloat(index * 8), y: CGFloat(index * 8))
                }
            }
        }
    }

    func code(values: ExampleValues) -> String {
        let spacing = ExampleFormat.number(values.cgFloat("spacing", default: 10))
        let items = values.int("items", default: 4)
        let alignment = values.int("alignment", default: 1)

        switch self {
        case .vStack:
            return """
            VStack(alignment: .\(horizontalAlignmentName(alignment)), spacing: \(spacing)) {
                ForEach(0..<\(items), id: \\.self) { index in
                    Text("Item \\(index)")
                }
            }
            """
        case .hStack:
            return """
            HStack(alignment: .\(verticalAlignmentName(alignment)), spacing: \(spacing)) {
                ForEach(0..<\(items), id: \\.self) { index in
                    Text("\\(index)")
                }
            }
            """
        case .zStack:
            return """
            ZStack {
                ForEach(0..<\(items), id: \\.self) { index in
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.blue.opacity(Double(index + 1) / \(max(items, 1))))
                        .frame(
                            width: CGFloat(130 - index * 20),
                            height: CGFloat(130 - index * 20)
                        )
                }
            }
            """
        }
    }

    private func horizontalAlignment(_ index: Int) -> HorizontalAlignment {
        switch index {
        case 0: .leading
        case 2: .trailing
        default: .center
        }
    }

    private func verticalAlignment(_ index: Int) -> VerticalAlignment {
        switch index {
        case 0: .top
        case 2: .bottom
        default: .center
        }
    }

    private func horizontalAlignmentName(_ index: Int) -> String {
        switch index {
        case 0: "leading"
        case 2: "trailing"
        default: "center"
        }
    }

    private func verticalAlignmentName(_ index: Int) -> String {
        switch index {
        case 0: "top"
        case 2: "bottom"
        default: "center"
        }
    }
}

enum ExampleFormat {
    static func number(_ value: CGFloat) -> String {
        number(Double(value))
    }

    static func number(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
        ? String(format: "%.0f", value)
        : String(format: "%.2f", value).trimmingTrailingZeros()
    }

    static func stringLiteral(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
        return "\"\(escaped)\""
    }

    static func percent(_ value: Double) -> String {
        value.formatted(.percent.precision(.fractionLength(0)))
    }
}

private extension String {
    func trimmingTrailingZeros() -> String {
        var value = self
        while value.contains(".") && value.last == "0" {
            value.removeLast()
        }
        if value.last == "." {
            value.removeLast()
        }
        return value
    }
}

// MARK: - Checkerboard Background

struct CheckerboardBackground: View {
    var body: some View {
        Canvas { context, size in
            let cell: CGFloat = 8
            let rows = Int(size.height / cell) + 1
            let cols = Int(size.width / cell) + 1
            for row in 0..<rows {
                for col in 0..<cols where (row + col).isMultiple(of: 2) {
                    let rect = CGRect(
                        x: CGFloat(col) * cell,
                        y: CGFloat(row) * cell,
                        width: cell,
                        height: cell
                    )
                    context.fill(Path(rect), with: .color(.primary.opacity(0.04)))
                }
            }
        }
    }
}

// MARK: - Developer Previews

private struct ExampleDeveloperPreview: View {
    let displayName: String
    let kind: SwiftUISymbolKind
    let examples: [SwiftUIExample]
    @State private var state = PlaygroundState()

    private var symbol: InteractiveSymbol {
        InteractiveSymbol(
            id: "preview.\(displayName)",
            displayName: displayName,
            kind: kind,
            examples: examples
        )
    }

    var body: some View {
        if let example = state.selectedExample(for: symbol) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if examples.count > 1 {
                        ExamplePicker(
                            examples: examples,
                            selection: Binding(
                                get: { state.selectedExampleID ?? example.id },
                                set: { state.selectExample(id: $0, for: symbol) }
                            )
                        )
                    }

                    LivePreviewCanvas(example: example, values: state.values(for: example))
                        .id(example.id)

                    DetailSectionForPreview(title: "Controls") {
                        example.controls(values: Binding(
                            get: { state.values(for: example) },
                            set: { state.valuesByExampleID[example.id] = $0 }
                        ))
                        .id(example.id)
                    }

                    HighlightedCodeBlock(title: "Generated Code", code: example.code(values: state.values(for: example)))
                }
                .padding()
            }
            .onAppear {
                state.prepare(for: symbol)
            }
        } else {
            ContentUnavailableView("No Examples", systemImage: "curlybraces.square")
        }
    }
}

private struct DetailSectionForPreview<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: .rect(cornerRadius: 8))
        }
    }
}

#Preview("Canvas Examples") {
    ExampleDeveloperPreview(
        displayName: "Canvas",
        kind: .view,
        examples: SwiftUIExampleCatalog.examples(kind: .view, symbolName: "Canvas")
    )
    .frame(width: 760, height: 760)
}

#Preview("Frame Modifier Example") {
    ExampleDeveloperPreview(
        displayName: "frame",
        kind: .modifier,
        examples: SwiftUIExampleCatalog.examples(kind: .modifier, symbolName: "frame")
    )
    .frame(width: 700, height: 640)
}
