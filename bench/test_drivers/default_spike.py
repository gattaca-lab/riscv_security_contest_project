import os

import runner_checks as rchecks

def run(libbench, opts, runner_override = None):
  tools = os.environ['DISTRIB_ROOT_DIR']
  spike_bin = os.path.join(tools, 'models/spike/bin/spike')

  print('running spike:')
  dbg_arg = ''
  if opts.dbg_enable_trace:
    dbg_arg = ' -l '

  sim_args = '-m0:256K --soc=beehive:uart_file=sim_uart.txt:id={} --pc=0 {}'.format(
              os.getcwd(), dbg_arg)
  img_path = os.path.join(os.getcwd(), 'test.elf')
  spike_cmd = '{} {} {} 2>exec.log '.format(spike_bin, sim_args, img_path)
  print(spike_cmd)

  ret = os.system(spike_cmd)

  if ret == 0:
    print('Great Success')
  else:
    if (opts.expect_failure):
      print('Not-So-Great Success')
    else:
      raise Exception('miserable failure')

  print("Working directory: {}".format(os.getcwd()))
  rchecks.RunnerChecks().check_uart('sim_uart.txt')
