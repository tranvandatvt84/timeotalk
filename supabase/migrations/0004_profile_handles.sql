alter table profiles
add column handle text;

alter table profiles
add constraint profiles_handle_format_check
check (
  handle is null
  or (
    handle = lower(handle)
    and handle ~ '^[a-z0-9_]{3,24}$'
  )
);

create unique index profiles_handle_unique_idx
on profiles (handle)
where handle is not null;
