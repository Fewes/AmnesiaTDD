#include "system/DebugUI.h"
#include "imgui.h"

namespace hpl
{
	bool DebugUI::open = false;

	int test = 0;

	void DebugUI::Toggle()
	{
		DebugUI::open = !DebugUI::open;
	}

	void DebugUI::DrawIfOpen(cEngine* engine)
	{
		if (!DebugUI::open)
		{
			return;
		}

		ImGui::SetNextWindowSize(ImVec2(500, 440), ImGuiCond_FirstUseEver);
		if (ImGui::Begin("Debug UI", &DebugUI::open, ImGuiWindowFlags_None))
		{
			ImGui::Combo("Debug Draw", &test,
				"None\0"
				"Diffuse\0"
				"Normals\0"
				"SSAO\0");

			/*
			if (ImGui::BeginMenuBar())
			{
				if (ImGui::BeginMenu("File"))
				{
					if (ImGui::MenuItem("Close", "Ctrl+W")) { DebugUI::open = false; }
					ImGui::EndMenu();
				}
				ImGui::EndMenuBar();
			}

			// Left
			static int selected = 0;
			{
				ImGui::BeginChild("left pane", ImVec2(150, 0), true);
				for (int i = 0; i < 100; i++)
				{
					// FIXME: Good candidate to use ImGuiSelectableFlags_SelectOnNav
					char label[128];
					sprintf(label, "MyObject %d", i);
					if (ImGui::Selectable(label, selected == i))
						selected = i;
				}
				ImGui::EndChild();
			}
			ImGui::SameLine();

			// Right
			{
				ImGui::BeginGroup();
				ImGui::BeginChild("item view", ImVec2(0, -ImGui::GetFrameHeightWithSpacing())); // Leave room for 1 line below us
				ImGui::Text("MyObject: %d", selected);
				ImGui::Separator();
				if (ImGui::BeginTabBar("##Tabs", ImGuiTabBarFlags_None))
				{
					if (ImGui::BeginTabItem("Description"))
					{
						ImGui::TextWrapped("Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. ");
						ImGui::EndTabItem();
					}
					if (ImGui::BeginTabItem("Details"))
					{
						ImGui::Text("ID: 0123456789");
						ImGui::EndTabItem();
					}
					ImGui::EndTabBar();
				}
				ImGui::EndChild();
				if (ImGui::Button("Revert")) {}
				ImGui::SameLine();
				if (ImGui::Button("Save")) {}
				ImGui::EndGroup();
			}
			*/
		}
		ImGui::End();
	}
}