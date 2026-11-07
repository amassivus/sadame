#include "notification.hpp"

#include "errors.hpp"

namespace sadame {

namespace {

struct Entry {
  std::string action, other_id, timing;
};

std::vector<Entry> entries(const Value &value, const std::string &resource_id, const std::string &option) {
  std::vector<Entry> result;
  if (value.is_nil()) return result;

  std::vector<Value> list;
  if (value.is_array() && !value.items().empty() && value.items()[0].is_array()) {
    list = value.items();
  } else {
    list.push_back(value);
  }

  for (const Value &entry : list) {
    bool valid = entry.is_array() && entry.items().size() >= 2 && entry.items().size() <= 3 &&
                 entry.items()[0].is_symbol() && entry.items()[1].is_string();
    if (!valid) {
      throw ResourceError(resource_id + ": #:" + option + " expects '(action \"type[name]\") " +
                          "or '(action \"type[name]\" immediately)");
    }
    std::string timing = "delayed";
    if (entry.items().size() == 3) {
      const Value &given = entry.items()[2];
      timing = given.is_symbol() ? given.text() : "";
      if (timing != "delayed" && timing != "immediately") {
        throw ResourceError(resource_id + ": #:" + option + " timing must be delayed or immediately, got " +
                            entry.items()[2].inspect());
      }
    }
    result.push_back({entry.items()[0].text(), entry.items()[1].text(), timing});
  }
  return result;
}

}  // namespace

std::vector<Notification> Notification::from_notifies(const Value &value, const std::string &resource_id) {
  std::vector<Notification> result;
  for (const Entry &entry : entries(value, resource_id, "notifies")) {
    result.push_back({entry.action, resource_id, entry.other_id, entry.timing, resource_id, "notifies"});
  }
  return result;
}

std::vector<Notification> Notification::from_subscribes(const Value &value, const std::string &resource_id) {
  std::vector<Notification> result;
  for (const Entry &entry : entries(value, resource_id, "subscribes")) {
    result.push_back({entry.action, entry.other_id, resource_id, entry.timing, resource_id, "subscribes"});
  }
  return result;
}

Value Notification::to_h() const {
  Value result = Value::map();
  result.set("action", action);
  result.set("source", source_id);
  result.set("target", target_id);
  result.set("timing", timing);
  return result;
}

}  // namespace sadame
