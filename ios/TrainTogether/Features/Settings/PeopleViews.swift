import SwiftUI
import TrainTogetherCore
import TrainTogetherKit

/// Edit a person, or create the partner when `personId` is nil.
struct PersonEditView: View {
    let personId: String?
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var color: PersonColor = .steel
    @State private var unit: WeightUnit = .kg
    @State private var sex: Sex?
    @State private var bodyweight: Double?

    var body: some View {
        let catalog = model.catalog
        let person = catalog.person(personId)
        let other = catalog.pair.first { $0.id != personId }
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PersonForm(name: $name, color: $color, unit: $unit, taken: other)
                BodyProfileFields(sex: $sex, bodyweight: $bodyweight, unit: unit)
                Button(person == nil ? "Save partner" : "Save changes", action: save)
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(20)
        }
        .paperBackground()
        .navigationTitle(person == nil ? "ADD PARTNER" : (person!.isOwner ? "YOU" : "PARTNER"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let person {
                name = person.name
                color = person.personColor
                unit = person.unit
                sex = person.sex
                bodyweight = person.bodyweight
            } else {
                color = PersonColor.allCases.first { $0 != other?.personColor } ?? .steel
            }
        }
    }

    private func save() {
        let ok = model.perform("SAVING") { engine in
            let body = BodyProfile(sex: sex, bodyweight: bodyweight)
            if let personId {
                try engine.updatePerson(id: personId, name: name, color: color, unit: unit, initials: "", body: body)
            } else {
                try engine.savePartner(name: name, color: color, unit: unit, body: body)
            }
        }
        if ok { dismiss() }
    }
}

/// Sex and bodyweight, used only for strength scores (the 1RM formula and
/// DOTS). Optional, never inferred. Bodyweight is in the selected unit and
/// isn't converted when the unit changes.
struct BodyProfileFields: View {
    @Binding var sex: Sex?
    @Binding var bodyweight: Double?
    let unit: WeightUnit

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("For strength scores")
            VStack(alignment: .leading, spacing: 8) {
                Text("Sex").metaStyle()
                Segmented(options: [(Sex?.none, "Not set"), (.male, Sex.male.label), (.female, Sex.female.label)], selection: $sex)
            }
            ValueInput(label: "Bodyweight · \(unit.rawValue)", value: $bodyweight, step: 0.5)
            Text("Picks the 1RM formula (Epley or Brzycki) and powers the DOTS score that compares the two of you fairly.")
                .font(Typeface.body(13))
                .foregroundStyle(Palette.textSecondary)
        }
    }
}

/// Name, identity color and unit — shared by onboarding and settings.
struct PersonForm: View {
    @Binding var name: String
    @Binding var color: PersonColor
    @Binding var unit: WeightUnit
    /// The other person, whose color can't be picked twice.
    let taken: Person?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Name").metaStyle()
                TextField("Name", text: $name)
                    .font(Typeface.display(28))
                    .textContentType(.givenName)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .card(radius: Radius.sm)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Color").metaStyle()
                HStack(spacing: 10) {
                    ForEach(PersonColor.allCases, id: \.self) { option in
                        let isTaken = taken?.personColor == option
                        Button { color = option } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: Radius.sm).fill(option.style.accent)
                                if isTaken {
                                    Text(taken?.initials ?? "").font(Typeface.display(18)).foregroundStyle(option.style.onAccent)
                                } else if option == color {
                                    Icon(.checkBig, size: 22).foregroundStyle(option.style.onAccent)
                                }
                            }
                            .frame(width: 48, height: 48)
                            .overlay(RoundedRectangle(cornerRadius: Radius.sm)
                                .strokeBorder(Palette.ink, lineWidth: option == color ? 3 : 0))
                            .opacity(isTaken ? 0.45 : 1)
                        }
                        .buttonStyle(.plain)
                        .disabled(isTaken)
                        .accessibilityLabel("\(option.label)\(isTaken ? ", taken by \(taken?.name ?? "")" : "")")
                        .accessibilityAddTraits(option == color ? .isSelected : [])
                    }
                }
                if let taken {
                    Text("\(taken.name)'s color is taken — pick a distinct one.")
                        .font(Typeface.body(13))
                        .foregroundStyle(Palette.textSecondary)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Weight unit").metaStyle()
                Segmented(options: [(WeightUnit.kg, "kg"), (.lb, "lb")], selection: $unit)
            }
        }
    }
}
