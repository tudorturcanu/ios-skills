// A stored callback stands in for a picker's selection handler.
final class PickerModel {
    var onSelect: (() -> Void)?
    var selections = 0

    func configure(retainsOwner: Bool) {
        if retainsOwner {
            onSelect = { self.selections += 1 }
        } else {
            onSelect = { [weak self] in self?.selections += 1 }
        }
    }
}

final class Probe {
    weak var model: PickerModel?
    init(_ model: PickerModel) { self.model = model }
}

func openAndDismiss(retainsOwner: Bool) -> Probe {
    let model = PickerModel()
    model.configure(retainsOwner: retainsOwner)
    model.onSelect?()
    precondition(model.selections == 1)
    return Probe(model)
}

for retainsOwner in [true, false] {
    let probes = (0..<5).map { _ in openAndDismiss(retainsOwner: retainsOwner) }
    let survivors = probes.filter { $0.model != nil }.count
    print("\(retainsOwner ? "Strong" : "Weak") capture: \(survivors) surviving models after five dismissals")
    precondition(survivors == (retainsOwner ? 5 : 0))
    for probe in probes { probe.model?.onSelect = nil }
}
