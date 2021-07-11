(import path)
(import err)
(import spork/regex :as re)

(defn dir-stat [p] 
  {:size (length (os/dir p))
   :modified ((os/stat p) :modified)})

(defn ls-r [dir]
  (def results @[])
  (def info (os/stat dir))

  (match info
    {:mode :file} (break @[{:path dir :info info}])
    {:mode :directory} 
    (array/push results
                {:path dir
                 :info (dir-stat dir) })
    _ (err/str "Cannot monitor filesystem entry of type " (info :mode)))

  (each p (os/dir dir)
    (def curr-path (path/join dir p))
    (def info (os/stat curr-path))
    (match info 
      {:mode :file} (array/push results {:path curr-path :info info})
      {:mode :directory} (array/concat results (ls-r curr-path))
      _ (eprint "Ignoring " p)))
    results)

(defn monitor [dirs ch] 
  (forever 
    (def to-watch (array/concat @[] ;(map |(ls-r $) dirs)))
    (prompt :hit-change
            (forever
              (ev/sleep 1)
              # (pp (map |($ :path) to-watch ))
              (each f to-watch 
                (var fresh (os/stat (f :path)))
                # (pp fresh)
                (unless fresh
                  # Indicates something got deleted
                  (break :hit-change))
                (when (= (fresh :mode) :directory)
                  (set fresh (dir-stat (f :path))))
                (def cached (f :info))
                (unless (and
                          (= (fresh :modified) (cached :modified))
                          (= (fresh :size) (cached :size)))
                  (ev/give ch (f :path))
                  (return :hit-change))))
            )))

(defn watch-stdin [out-ch]
  (forever
    (def input (ev/thread (ev/call |(:read stdin :line))))
    (match (string/trim input)
      "Q" (ev/give out-ch :quit)
      "q" (ev/give out-ch :quit))))

(defn watch [dirs cmd]
  # First, we recursively list out the directory into an array
  (def change-chan (ev/chan 1))
  (ev/call monitor dirs change-chan)

  (def quit-chan (ev/chan 1))
  # (ev/call watch-stdin quit-chan)
  (var sub-proc (os/spawn cmd :p))

  (forever 
    (match (ev/select quit-chan change-chan)
      [:take quit-chan :quit]
      (do 
        (:kill sub-proc)
        (:wait sub-proc)
        (os/exit 0))
      [:take change-chan data]
      (do
        (:kill sub-proc)
        (:wait sub-proc)
        (set sub-proc (os/spawn cmd :p)))
      )))
  

(defn usage [] 
  (print ```
         eye [list of dirs and files to watch] --cmd [command to run on change]
         ```))

(defn usage-error [args] 
  (printf "Didn't understand some part of %j" args)
  (usage))

(defn get-kv [args k] 
  (get args (+ 1 (index-of k args))))

(defn main [_ & args]
  (def cmd-idx (index-of "--cmd" args))
  
  (unless cmd-idx 
    (usage-error args))

  (def to-watch (slice args 0 cmd-idx))
  (def cmd (slice args (+ 1 cmd-idx)))
  (watch to-watch cmd))
