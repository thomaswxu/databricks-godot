#ifndef DATABRICKS_GODOT_H
#define DATABRICKS_GODOT_H

#include <godot_cpp/classes/node.hpp>

namespace godot {

class Databricks : public Node {
	GDCLASS(Databricks, Node)

public:
	Databricks();
	~Databricks();

	void _process(double delta) override;

    double get_test_property() const;
    void set_test_property(double value);

protected:
	static void _bind_methods();

private:
	double test_property_ = 0.0;
};

} // namespace godot

#endif // DATABRICKS_GODOT_H
