#ifndef DATABRICKS_GODOT_REGISTER_TYPES_H
#define DATABRICKS_GODOT_REGISTER_TYPES_H

#include <godot_cpp/core/class_db.hpp>

using namespace godot;

void initialize_gdextension_modules(ModuleInitializationLevel p_level);
void uninitialize_gdextension_modules(ModuleInitializationLevel p_level);

#endif // DATABRICKS_GODOT_REGISTER_TYPES_H
