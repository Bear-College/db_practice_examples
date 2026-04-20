"""
Ключі / Keys — primary key, unique, composite PK, foreign keys.

Run: python example.py
"""
from __future__ import annotations

from sqlalchemy import (
    ForeignKey,
    ForeignKeyConstraint,
    PrimaryKeyConstraint,
    String,
    UniqueConstraint,
    create_engine,
    select,
)
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship, Session


class Base(DeclarativeBase):
    pass


class User(Base):
    """Surrogate primary key + natural unique (email)."""

    __tablename__ = "users"
    __table_args__ = (UniqueConstraint("email", name="uq_users_email"),)

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    email: Mapped[str] = mapped_column(String(120))
    name: Mapped[str] = mapped_column(String(80))


class Membership(Base):
    """Composite primary key (user_id, team_id) — typical junction metadata."""

    __tablename__ = "memberships"
    __table_args__ = (
        PrimaryKeyConstraint("user_id", "team_id", name="pk_memberships"),
        ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
    )

    user_id: Mapped[int] = mapped_column()
    team_id: Mapped[int] = mapped_column()
    role: Mapped[str] = mapped_column(String(40), default="member")


class Post(Base):
    """Foreign key to users.id — many posts per user."""

    __tablename__ = "posts"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"))
    title: Mapped[str] = mapped_column(String(200))

    author: Mapped[User] = relationship(back_populates="posts")


User.posts = relationship("Post", back_populates="author", cascade="all, delete-orphan")


def main() -> None:
    engine = create_engine("sqlite:///02_keys_lab.db", echo=False)
    Base.metadata.drop_all(engine)
    Base.metadata.create_all(engine)

    with Session(engine) as session:
        u = User(email="ada@example.com", name="Ada")
        session.add(u)
        session.flush()
        session.add_all(
            [
                Post(user_id=u.id, title="First"),
                Post(user_id=u.id, title="Second"),
                Membership(user_id=u.id, team_id=1, role="owner"),
            ]
        )
        session.commit()

    with Session(engine) as session:
        u = session.scalars(select(User).where(User.email == "ada@example.com")).one()
        print("User:", u.id, u.email, "posts:", len(u.posts))


if __name__ == "__main__":
    main()
