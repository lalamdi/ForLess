//
//  SavedLocationsView.swift
//  ForLess
//
//  Created by Leen Almeadadi on 06/11/2026.
//


//  Customer "Saved locations" screen, opened from Profile.
//  Lists the saved addresses. The pencil opens the address to edit or delete it,
//  and the button at the bottom adds a new one.
//
 
import SwiftUI
 
struct SavedLocationsView: View {
    @EnvironmentObject private var auth: AuthManager
    @State private var editor: EditorTarget?   // which address the editor sheet shows
 
    /// What the editor sheet opens: an existing address, or nothing for a new one.
    struct EditorTarget: Identifiable {
        let id = UUID()
        let place: SavedLocation?
    }
 
    private var places: [SavedLocation] {
        auth.profile?.savedLocations ?? []
    }
 
    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                if places.isEmpty {
                    Text("No saved addresses yet.")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.muted)
                        .padding(.top, 24)
                }
 
                ForEach(places, id: \.self) { place in
                    addressCard(place)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(Color.appBackground)
        .navigationTitle("Saved locations")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button {
                editor = EditorTarget(place: nil)
            } label: {
                Label("Add new address", systemImage: "plus")
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(Color.appBackground)
        }
        .sheet(item: $editor) { target in
            AddAddressView(editing: target.place)
        }
    }
 
    /// One address with a pencil on the right.
    private func addressCard(_ place: SavedLocation) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.appBackground)
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: icon(for: place.label))
                        .font(.system(size: 16))
                        .foregroundStyle(Color.ink)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(place.label)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.ink)
                Text(place.address)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.muted)
                    .lineLimit(2)
            }
            Spacer()
            Button {
                editor = EditorTarget(place: place)
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.brandText)
                    .frame(width: 36, height: 36)
                    .background(Color.brandLight, in: Circle())
            }
            .accessibilityLabel("Edit \(place.label)")
        }
        .padding(12)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
    }
 
    private func icon(for label: String) -> String {
        switch label {
        case "Home": return "house"
        case "Work": return "briefcase"
        default: return "mappin"
        }
    }
}
