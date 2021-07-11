(declare-project :name "eye" 
                 :description "eye watches your files, and re-runs a command when they change"
                 :dependencies ["path"])

(declare-executable :name "eye" :entry "eye.janet")
