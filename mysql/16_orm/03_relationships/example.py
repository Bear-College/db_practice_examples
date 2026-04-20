"""
Типи зв'язків / Relationship types — one-to-many, many-to-many, one-to-one.

Run: python example.py
"""
from __future__ import annotations

from typing import List

from sqlalchemy import ForeignKey, String, Table, Column, create_engine, select
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship, Session


class Base(DeclarativeBase):
    pass


# Many-to-many association table
student_course = Table(
    "student_course",
    Base.metadata,
    Column("student_id", ForeignKey("students.id", ondelete="CASCADE"), primary_key=True),
    Column("course_id", ForeignKey("courses.id", ondelete="CASCADE"), primary_key=True),
)


class Student(Base):
    __tablename__ = "students"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    name: Mapped[str] = mapped_column(String(80))
    courses: Mapped[List["Course"]] = relationship(secondary=student_course, back_populates="students")


class Course(Base):
    __tablename__ = "courses"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    code: Mapped[str] = mapped_column(String(20))
    students: Mapped[List[Student]] = relationship(secondary=student_course, back_populates="courses")


class Author(Base):
    """One author — many books (one-to-many / many-to-one)."""

    __tablename__ = "authors"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    name: Mapped[str] = mapped_column(String(80))
    books: Mapped[List["Book"]] = relationship(back_populates="author", cascade="all, delete-orphan")


class Book(Base):
    __tablename__ = "books"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    title: Mapped[str] = mapped_column(String(200))
    author_id: Mapped[int] = mapped_column(ForeignKey("authors.id"))
    author: Mapped[Author] = relationship(back_populates="books")


class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    login: Mapped[str] = mapped_column(String(40), unique=True)
    profile: Mapped["Profile | None"] = relationship(back_populates="user", uselist=False, cascade="all, delete-orphan")


class Profile(Base):
    """One-to-one: single profile row per user (uselist=False on User.profile)."""

    __tablename__ = "profiles"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), unique=True)
    bio: Mapped[str] = mapped_column(String(500))
    user: Mapped[User] = relationship(back_populates="profile")


def main() -> None:
    engine = create_engine("sqlite:///03_relationships_lab.db", echo=False)
    Base.metadata.drop_all(engine)
    Base.metadata.create_all(engine)

    with Session(engine) as session:
        a = Author(name="Le Guin")
        a.books.extend([Book(title="The Left Hand of Darkness"), Book(title="The Dispossessed")])
        session.add(a)

        s1 = Student(name="Sam")
        c1 = Course(code="DB-101")
        c2 = Course(code="PY-202")
        s1.courses.extend([c1, c2])
        session.add_all([s1, c1, c2])

        u = User(login="neo")
        u.profile = Profile(bio="The One")
        session.add(u)
        session.commit()

    with Session(engine) as session:
        a = session.get(Author, 1)
        print("Author → books:", a.name, [b.title for b in a.books])
        s = session.get(Student, 1)
        print("Student ↔ courses:", s.name, [c.code for c in s.courses])
        u = session.scalars(select(User).where(User.login == "neo")).one()
        print("User 1–1 profile:", u.login, u.profile.bio if u.profile else None)


if __name__ == "__main__":
    main()
