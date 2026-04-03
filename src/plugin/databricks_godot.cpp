#include "databricks_godot.h"
#include <godot_cpp/core/class_db.hpp>

using namespace godot;

Databricks::Databricks() {
	// Initialize any variables here.
    test_property_ = 0.0;
}

Databricks::~Databricks() {
	// Add your cleanup here.
}

double Databricks::get_test_property() const {
    return test_property_;
}

void Databricks::set_test_property(double value) {
    test_property_ = value;
}

void Databricks::_process(double delta) {
}

void Databricks::_bind_methods() {
    ClassDB::bind_method(D_METHOD("get_test_property"), &Databricks::get_test_property);
	ClassDB::bind_method(D_METHOD("set_test_property", "value"), &Databricks::set_test_property);

	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "test_property", PROPERTY_HINT_RANGE, "0,20,0.5"), "set_test_property", "get_test_property");
}
