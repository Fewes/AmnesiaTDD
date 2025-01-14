#ifndef HPL_DEBUGUI_H
#define HPL_DEBUGUI_H

#include "LowLevelSystem.h"
#include "engine/Engine.h"

namespace hpl
{
	class DebugUI
	{
	public:
		static bool open;

		static void Toggle();
		static void Update(cEngine*);
	private:
		static bool prevOpen;
	};
}
#endif