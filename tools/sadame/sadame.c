/*
 * Entry point of the sadame binary. All logic lives in Ruby; this file only
 * builds ARGV, calls Sadame.main and turns its return value into the
 * process exit status.
 */
#include <stdio.h>
#include <mruby.h>
#include <mruby/array.h>
#include <mruby/string.h>
#include <mruby/variable.h>

int
main(int argc, char **argv)
{
  mrb_state *mrb = mrb_open();
  mrb_value args;
  mrb_value result;
  int status = 0;
  int i;

  if (mrb == NULL) {
    fputs("sadame: could not initialize the mruby interpreter\n", stderr);
    return 2;
  }

  args = mrb_ary_new_capa(mrb, argc - 1);
  for (i = 1; i < argc; i++) {
    mrb_ary_push(mrb, args, mrb_str_new_cstr(mrb, argv[i]));
  }
  mrb_define_global_const(mrb, "ARGV", args);

  result = mrb_funcall(mrb, mrb_obj_value(mrb_module_get(mrb, "Sadame")), "main", 1, args);
  if (mrb->exc) {
    mrb_print_error(mrb);
    status = 2;
  }
  else if (mrb_integer_p(result)) {
    status = (int)mrb_integer(result);
  }

  mrb_close(mrb);
  return status;
}
