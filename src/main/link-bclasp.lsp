(select-package :core)
(load-system :start :min)
(if (member :ecl-min *features*) (bclasp-features))
(let ((*target-backend* (default-target-backend)))
  (load-system :init :all)
  (link-system :init :all (default-prologue-form '(:clos)) (default-epilogue-form)))
(quit)
