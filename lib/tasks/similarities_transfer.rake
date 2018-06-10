# frozen_string_literal: true

desc "Import production DB's entries"
task :import_entries do
  system <<~SHELL
    target_date=$(date "+%Y-%m-%d")
    ssh portalshit.net 'mysqldump -u portalshit -p#{Lokka.dsh['password']} portalshit entries --default-character-set=utf8mb4 | gzip' > db/${target_date}-entries.sql.gz
    gunzip db/${target_date}-entries.sql.gz
    mysql -u portalshit -p#{Lokka.dsh['password']} portalshit < db/${target_date}-entries.sql
    rm db/${target_date}-entries.sql*
  SHELL
end

desc 'Export similarities to production DB'
task :export_similarities do
  system <<~SHELL
    target_date=$(date "+%Y-%m-%d")
    mysqldump -uportalshit -p#{Lokka.dsh['password']} portalshit similarities | gzip > db/${target_date}-similarities.sql.gz
    scp db/${target_date}-similarities.sql.gz portalshit.net:sites/portalshit/db/
    ssh portalshit.net "gunzip -f ~/sites/portalshit/db/${target_date}-similarities.sql.gz &&
     mysql -u portalshit -p#{Lokka.dsh['password']} portalshit < ~/sites/portalshit/db/${target_date}-similarities.sql &&
     rm -rf ~/sites/portalshit/db/${target_date}-similarities.sql*"
  SHELL
end
